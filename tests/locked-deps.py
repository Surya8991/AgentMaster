"""Exercise real locked install/update entrypoints against local Git fixtures."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def run(command, **kwargs):
    return subprocess.run(command, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, **kwargs)


def replace_fixture_path(text, original, replacement):
    """Fail before execution if an entrypoint no longer matches its sandbox hook."""
    assert text.count(original) == 1, f'Cannot isolate entrypoint path: {original}'
    return text.replace(original, replacement)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bash', default='bash')
    parser.add_argument('--powershell', default='pwsh')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='agentmaster-locked-') as temporary:
        temp = Path(temporary)
        upstream = temp / 'upstream'
        upstream.mkdir()
        def git(*arguments):
            result = run(['git', '-C', str(upstream), *arguments])
            assert result.returncode == 0, result.stdout
            return result.stdout.strip()
        git('init', '-q')
        git('config', 'user.name', 'Fixture')
        git('config', 'user.email', 'fixture@example.invalid')
        skill = upstream / 'skills' / 'sample' / 'SKILL.md'
        skill.parent.mkdir(parents=True)
        skill.write_text('---\nname: sample\ndescription: fixture\n---\nlocked\n', encoding='utf-8')
        git('add', '.')
        git('commit', '-qm', 'locked')
        pin = git('rev-parse', 'HEAD')
        skill.write_text('---\nname: sample\ndescription: fixture\n---\nlatest\n', encoding='utf-8')
        git('commit', '-qam', 'latest')
        latest = git('rev-parse', 'HEAD')
        for engine in ('bash', 'powershell'):
            for mode in ('install', 'update'):
                cases = ['missing', 'invalid', 'wrong', 'valid']
                if mode == 'update':
                    cases.append('ordinary-wrong')
                for case in cases:
                    base = temp / f'{engine}-{mode}-{case}'
                    source = base / 'source'
                    cache = base / 'cache'
                    installed = base / 'installed'
                    source.mkdir(parents=True)
                    cache.mkdir()
                    installed.mkdir()
                    (installed / 'sentinel').write_text('untouched', encoding='utf-8')
                    shutil.copytree(ROOT / 'scripts', source / 'scripts')
                    for filename in ('install.sh', 'install.ps1'):
                        shutil.copyfile(ROOT / filename, source / filename)
                    own = source / 'skills' / 'agent-master' / 'SKILL.md'
                    own.parent.mkdir(parents=True)
                    own.write_text('---\nname: agent-master\ndescription: fixture\n---\nlocal source\n', encoding='utf-8')
                    (source / 'repos.manifest').write_text(f'dep|{upstream.as_uri()}|skills\n', encoding='utf-8')
                    (source / 'profiles.manifest').write_text('', encoding='utf-8')
                    # A lock overrides ambient pins and an active cooldown.
                    (cache / 'pins.local').write_text(f'dep={latest}\n', encoding='utf-8')
                    (cache / '.last-update').write_text(str(int(time.time())), encoding='utf-8')
                    relative = f'{mode}.sh' if mode == 'install' else 'scripts/update.sh'
                    if engine == 'powershell':
                        relative = relative.replace('.sh', '.ps1')
                    entry = source / relative
                    text = entry.read_text(encoding='utf-8')
                    if engine == 'bash':
                        def shell_path(path):
                            if os.name != 'nt':
                                return str(path)
                            converted = run([args.bash, '-c', 'cygpath -u "$1"', '--', str(path)])
                            assert converted.returncode == 0, converted.stdout
                            return converted.stdout.strip()
                        text = replace_fixture_path(text, 'SKILLS_DIR="$HOME/.claude/skills"', f'SKILLS_DIR="{shell_path(installed)}"')
                        text = replace_fixture_path(text, 'CACHE_DIR="$HOME/.claude/.agentmaster-cache"', f'CACHE_DIR="{shell_path(cache)}"')
                        (source / 'repos.manifest').write_text(f'dep|file://{shell_path(upstream)}|skills\n', encoding='utf-8')
                        command = [args.bash, str(entry)]
                    else:
                        text = replace_fixture_path(text, "$SkillsDir = Join-Path $HOME '.claude/skills'", f"$SkillsDir = '{installed.as_posix()}'")
                        text = replace_fixture_path(text, "$CacheDir = Join-Path $HOME '.claude/.agentmaster-cache'", f"$CacheDir = '{cache.as_posix()}'")
                        command = [args.powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(entry)]
                    entry.write_bytes(text.encode('utf-8'))
                    environment = os.environ.copy()
                    # Do not inherit a machine-specific global ignore path (which
                    # may be unreadable in a sandbox and emits native stderr).
                    ignore = base / 'empty-ignore'
                    ignore.write_text('', encoding='utf-8')
                    environment['GIT_CONFIG_COUNT'] = '1'
                    environment['GIT_CONFIG_KEY_0'] = 'core.excludesFile'
                    environment['GIT_CONFIG_VALUE_0'] = str(ignore)
                    environment['AGENTMASTER_LOCKED'] = '1'
                    environment['AGENTMASTER_LOCK_PINS'] = {
                        'missing': '', 'invalid': 'dep=main',
                        'wrong': 'dep=' + '0' * 40, 'valid': f'dep={pin}',
                        'ordinary-wrong': '',
                    }[case]
                    if case == 'ordinary-wrong':
                        environment.pop('AGENTMASTER_LOCKED', None)
                        environment.pop('AGENTMASTER_LOCK_PINS', None)
                        (cache / '.last-update').unlink()
                        (cache / 'pins.local').write_text('dep=' + '0' * 40 + '\n', encoding='utf-8')
                        # An ordinary updater self-cache with a local remote avoids
                        # changing entrypoint control flow or requiring the network.
                        for arguments in [('init', '-q'), ('add', '.'),
                                          ('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'source')]:
                            prepared = run(['git', '-C', str(source), *arguments])
                            assert prepared.returncode == 0, prepared.stdout
                        prepared = run(['git', 'clone', '-q', str(source), str(cache / 'agent-master')])
                        assert prepared.returncode == 0, prepared.stdout
                    result = run(command, cwd=source, env=environment)
                    if case == 'valid':
                        assert result.returncode == 0, f'{engine} {mode}: {result.stdout}'
                        assert (installed / 'sample' / 'SKILL.md').read_text(encoding='utf-8').endswith('locked\n'), result.stdout
                        assert (installed / 'agent-master' / 'SKILL.md').exists(), result.stdout
                        # PowerShell providers normalize backslashes on Unix, but
                        # native Git and .NET do not. Verify the shared paths really
                        # address the same cache/ownership/provenance files.
                        owners = (cache / '.skill-owners').read_text(encoding='utf-8-sig')
                        assert 'sample=dep' in owners.splitlines(), result.stdout
                        metadata = (cache / '.provenance' / 'sample.txt').read_text(encoding='utf-8-sig')
                        assert f'commit={pin}' in metadata.splitlines(), result.stdout
                        assert 'repo=dep' in metadata.splitlines(), result.stdout
                        checked_out = run(['git', '-C', str(cache / 'dep'), 'rev-parse', 'HEAD'])
                        assert checked_out.returncode == 0 and checked_out.stdout.strip() == pin, checked_out.stdout
                        assert not any('\\' in path.name for path in base.rglob('*')), 'Windows separator became a literal Unix filename'
                    elif case == 'ordinary-wrong':
                        assert result.returncode != 0, result.stdout
                        assert not (installed / 'sample').exists(), result.stdout
                        assert 'pin ' + '0' * 40 in result.stdout, result.stdout
                    else:
                        assert result.returncode != 0, f'{engine} {mode} accepted {case}: {result.stdout}'
                        assert sorted(p.name for p in installed.iterdir()) == ['sentinel'], result.stdout
                    print(f'PASS {engine} locked {mode}: {case}', flush=True)


if __name__ == '__main__':
    main()
