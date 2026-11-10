#!/usr/bin/env python3
"""OSXER APPS (logging regression): opt-in and once-only semantics under contention.
Run under the workspace build wrapper, so TMPDIR and the memory guard are set.
"""
from pathlib import Path
import os
import subprocess
import tempfile
source = Path(__file__).resolve().parents[2] / 'src/include'
tmp = Path(os.environ['TMPDIR']).resolve()
assert tmp != Path('/tmp') and Path('/tmp') not in tmp.parents
with tempfile.TemporaryDirectory(prefix='app-gaps-log-', dir=tmp) as name:
    work = Path(name)
    code = work / 'probe.c'
    code.write_text('''#include <darling/osxer-apps.h>
#include <pthread.h>
static void *worker(void *unused) {
    for (int i = 0; i < 10000; ++i) { OSXER_APPS_STUB("unavailable"); }
    return NULL;
}
int main(void) {
    pthread_t threads[16];
    for (int i = 0; i < 16; ++i) if (pthread_create(&threads[i], NULL, worker, NULL)) return 1;
    for (int i = 0; i < 16; ++i) if (pthread_join(threads[i], NULL)) return 2;
    return 0;
}
''')
    exe = work / 'probe'
    subprocess.run(['/usr/bin/clang', '-O2', '-pthread', '-I' + str(source), str(code), '-o', str(exe)], check=True)
    for setting in [None, '0', 'true', '1']:
        env = dict(os.environ)
        env.pop('OSXER_LOG_STDERR', None)
        if setting is not None: env['OSXER_LOG_STDERR'] = setting
        result = subprocess.run([str(exe)], env=env, capture_output=True, text=True, check=True)
        assert not result.stdout
        expected = 'OSXER APPS (worker): unavailable\n' if setting == '1' else ''
        assert result.stderr == expected, (setting, result.stderr)
print('PASS logging: 16 threads, exact opt-in, one line per process')
