/* OSXER PREFIX (native test): exercise the launcher's real pre-start path.
 * Only credentials/account lookup are substituted; filesystem I/O is real.
 * No Darling runtime, namespaces, services, or host account files are used.
 */
#include <assert.h>
#include <stdbool.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

extern int darling_launcher_main(int argc, char** argv);
extern bool g_fixPermissions;
static bool wrong_owner;

uid_t __wrap_geteuid(void) { return 0; }
int __wrap_setuid(uid_t uid) { assert(uid == 0); return 0; }
int __wrap_setgid(gid_t gid) { assert(gid == 0); return 0; }
int __wrap_seteuid(uid_t uid) { assert(uid == 0 || uid == getuid()); return 0; }
int __wrap_setegid(gid_t gid) { assert(gid == 0 || gid == getgid()); return 0; }

struct passwd* __wrap_getpwuid(uid_t uid)
{
	static struct passwd account;
	account.pw_name = "prefix-test-user";
	account.pw_uid = uid;
	account.pw_gid = getgid();
	return &account;
}

int __real_stat(const char* path, struct stat* st);
int __wrap_stat(const char* path, struct stat* st)
{
	int result = __real_stat(path, st);
	if (result == 0 && wrong_owner)
		st->st_uid = getuid() + 1;
	return result;
}

int __wrap_unshare(int flags)
{
	(void) flags;
	fputs("FAIL: test reached namespace setup\n", stderr);
	_exit(99);
}

static void report_changes(void)
{
	printf("PREFIX_CHANGED=%d\n", g_fixPermissions);
}

int main(int argc, char** argv)
{
	assert(argc == 2 || argc == 3);
	assert(getuid() != 0);  /* This test never needs root. */
	wrong_owner = argc == 3 && strcmp(argv[2], "wrong-owner") == 0;
	assert(setenv("DPREFIX", argv[1], 1) == 0);
	assert(atexit(report_changes) == 0);
	/* --help exits after prefix initialization, before PID/socket handling. */
	char* args[] = { "prefix-native-test", "--help", NULL };
	return darling_launcher_main(2, args);
}
