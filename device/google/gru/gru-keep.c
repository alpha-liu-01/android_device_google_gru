#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/sysmacros.h>
#include <linux/watchdog.h>
#include <unistd.h>

#define WATCHDOG_TIMEOUT 30
#define LOG_PATH "/bootlog/gru-phase3.log"

static int log_fd = -1;
static char early[8192];
static size_t early_len;

static void write_all(int fd, const char *buf, size_t len) {
    while (len > 0) {
        ssize_t wrote = write(fd, buf, len);
        if (wrote < 0) {
            if (errno == EINTR) {
                continue;
            }
            return;
        }
        buf += wrote;
        len -= (size_t)wrote;
    }
}

static void log_text(const char *text) {
    size_t len = strlen(text);
    if (log_fd < 0) {
        if (early_len + len < sizeof(early)) {
            memcpy(early + early_len, text, len);
            early_len += len;
        }
        return;
    }
    if (early_len > 0) {
        write_all(log_fd, early, early_len);
        early_len = 0;
    }
    write_all(log_fd, text, len);
}

static void log_err(const char *what, int err) {
    char line[192];
    snprintf(line, sizeof(line), "%s=%s\n", what, err == 0 ? "ok" : strerror(err));
    log_text(line);
}

static int load_module(const char *path) {
    int fd = open(path, O_RDONLY);
    int err;
    if (fd < 0) {
        return errno;
    }
    err = syscall(SYS_finit_module, fd, "", 0) == 0 ? 0 : errno;
    close(fd);
    return err;
}

static int mount_fs(const char *where, const char *type) {
    mkdir(where, 0755);
    if (mount(type, where, type, 0, NULL) != 0 && errno != EBUSY) {
        return errno;
    }
    return 0;
}

static int parse_int(const char *buf, const char *key) {
    const char *found = strstr(buf, key);
    if (found == NULL) {
        return -1;
    }
    return atoi(found + strlen(key));
}

static int ensure_node(const char *disk, int major, int minor) {
    char node[288];
    snprintf(node, sizeof(node), "/dev/%s", disk);
    if (access(node, F_OK) == 0) {
        return 0;
    }
    mkdir("/dev", 0755);
    if (mknod(node, S_IFBLK | 0600, makedev(major, minor)) != 0 && errno != EEXIST) {
        return errno;
    }
    return 0;
}

static int find_part(const char *name, char *node, size_t node_len) {
    DIR *dir = opendir("/gru-sys/class/block");
    struct dirent *entry;
    char want[80];
    if (dir == NULL) {
        return errno;
    }
    snprintf(want, sizeof(want), "PARTNAME=%s", name);
    while ((entry = readdir(dir)) != NULL) {
        char path[320];
        char buf[512];
        ssize_t got;
        int fd;
        int major;
        int minor;
        if (entry->d_name[0] == '.') {
            continue;
        }
        snprintf(path, sizeof(path), "/gru-sys/class/block/%s/uevent", entry->d_name);
        fd = open(path, O_RDONLY);
        if (fd < 0) {
            continue;
        }
        got = read(fd, buf, sizeof(buf) - 1);
        close(fd);
        if (got <= 0) {
            continue;
        }
        buf[got] = '\0';
        if (strstr(buf, want) == NULL) {
            continue;
        }
        major = parse_int(buf, "MAJOR=");
        minor = parse_int(buf, "MINOR=");
        if (major < 0 || minor < 0 || ensure_node(entry->d_name, major, minor) != 0) {
            closedir(dir);
            return errno != 0 ? errno : ENODEV;
        }
        snprintf(node, node_len, "/dev/%s", entry->d_name);
        closedir(dir);
        return 0;
    }
    closedir(dir);
    return ENODEV;
}

static void list_blocks(void) {
    DIR *dir = opendir("/gru-sys/class/block");
    struct dirent *entry;
    log_text("blocks:\n");
    if (dir == NULL) {
        log_err("blocks_open", errno);
        return;
    }
    while ((entry = readdir(dir)) != NULL) {
        char path[320];
        char buf[512];
        char line[160];
        ssize_t got;
        int fd;
        char *part;
        if (entry->d_name[0] == '.') {
            continue;
        }
        snprintf(path, sizeof(path), "/gru-sys/class/block/%s/uevent", entry->d_name);
        fd = open(path, O_RDONLY);
        if (fd < 0) {
            continue;
        }
        got = read(fd, buf, sizeof(buf) - 1);
        close(fd);
        if (got <= 0) {
            continue;
        }
        buf[got] = '\0';
        part = strstr(buf, "PARTNAME=");
        if (part != NULL) {
            char *end = strchr(part, '\n');
            if (end != NULL) {
                *end = '\0';
            }
        }
        snprintf(line, sizeof(line), " %.64s %.80s\n", entry->d_name, part != NULL ? part : "nopart");
        log_text(line);
    }
    closedir(dir);
}

static void append_file(const char *label, const char *path) {
    char buf[512];
    int fd = open(path, O_RDONLY);
    ssize_t got;
    log_text(label);
    if (fd < 0) {
        log_err("read", errno);
        return;
    }
    got = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (got < 0) {
        log_err("read", errno);
        return;
    }
    buf[got] = '\0';
    log_text(buf);
    if (got == 0 || buf[got - 1] != '\n') {
        log_text("\n");
    }
}

static int open_bootlog(void) {
    char node[288];
    int err = find_part("bootlog", node, sizeof(node));
    if (err != 0) {
        return err;
    }
    mkdir("/bootlog", 0755);
    if (mount(node, "/bootlog", "ext4", MS_NOATIME, NULL) != 0 && errno != EBUSY) {
        return errno;
    }
    log_fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC | O_SYNC, 0644);
    if (log_fd < 0) {
        return errno;
    }
    return 0;
}

static void drain_kmsg(int kmsg) {
    char buf[4096];
    for (;;) {
        ssize_t got = read(kmsg, buf, sizeof(buf));
        if (got < 0) {
            if (errno == EINTR) {
                continue;
            }
            return;
        }
        if (got == 0) {
            return;
        }
        write_all(log_fd, buf, (size_t)got);
        if (buf[got - 1] != '\n') {
            write_all(log_fd, "\n", 1);
        }
    }
}

static void handoff_watchdog_to_kernel(int *watchdog) {
    if (*watchdog < 0) {
        return;
    }
    /* dw_wdt has no reset line on RK3399, so dw_wdt_stop() sets WDOG_HW_RUNNING
       and returns 0. Writing magic 'V' before close() (and WDIOS_DISABLECARD)
       makes watchdog_release() call watchdog_stop(), which clears WDOG_ACTIVE
       while leaving WDOG_HW_RUNNING set and open_deadline = KTIME_MAX. The
       kernel's non-freezable RT [watchdogd] kthread then feeds dw_wdt every
       ~10.7s forever, including across userspace freeze during S3 suspend. */
    int opt = WDIOS_DISABLECARD;
    ioctl(*watchdog, WDIOC_SETOPTIONS, &opt);
    write_all(*watchdog, "V", 1);
    close(*watchdog);
    *watchdog = -1;
}

int main(int argc, char **argv) {
    int watchdog = -1;
    int kmsg = -1;
    int waited;
    int super_err = ENODEV;
    char super_node[288];
    char line[64];
    mkdir("/dev", 0755);
    mknod("/dev/kmsg", S_IFCHR | 0600, makedev(1, 11));
    kmsg = open("/dev/kmsg", O_RDWR | O_NONBLOCK);

    log_err("watchdog_ko", load_module("/watchdog.ko"));
    log_err("dw_wdt_ko", load_module("/dw_wdt.ko"));
    mknod("/dev/watchdog", S_IFCHR | 0600, makedev(10, 130));
    watchdog = open("/dev/watchdog", O_WRONLY);
    log_err("watchdog_open", watchdog < 0 ? errno : 0);
    if (watchdog >= 0) {
        int timeout = WATCHDOG_TIMEOUT;
        log_err("watchdog_timeout", ioctl(watchdog, WDIOC_SETTIMEOUT, &timeout) == 0 ? 0 : errno);
        ioctl(watchdog, WDIOC_KEEPALIVE, 0);
    }

    log_err("proc", mount_fs("/gru-proc", "proc"));
    log_err("sysfs", mount_fs("/gru-sys", "sysfs"));
    for (waited = 0; waited < 45; waited++) {
        if (open_bootlog() == 0) {
            break;
        }
        if (find_part("super", super_node, sizeof(super_node)) == 0) {
            /* Storage controller has probed; try bootlog once more in case of
               a partition registration race, then continue even if absent. */
            open_bootlog();
            break;
        }
        if (watchdog >= 0) {
            ioctl(watchdog, WDIOC_KEEPALIVE, 0);
        }
        sleep(1);
    }
    log_text("GRUDIAG2\n");
    snprintf(line, sizeof(line), "bootlog_wait=%d\n", waited);
    log_text(line);
    append_file("version ", "/gru-proc/version");
    append_file("cmdline ", "/gru-proc/cmdline");
    list_blocks();

    for (; waited < 45; waited++) {
        super_err = find_part("super", super_node, sizeof(super_node));
        if (super_err == 0) {
            break;
        }
        if (watchdog >= 0) {
            ioctl(watchdog, WDIOC_KEEPALIVE, 0);
        }
        sleep(1);
    }
    snprintf(line, sizeof(line), "super_wait=%d\n", waited);
    log_text(line);
    log_err("super", super_err);
    list_blocks();
    if (kmsg >= 0 && log_fd >= 0) {
        log_text("kmsg:\n");
        lseek(kmsg, 0, SEEK_SET);
        drain_kmsg(kmsg);
    }
    if (log_fd >= 0) {
        fsync(log_fd);
    }
    sync();

    if (super_err != 0) {
        log_text("android_not_started super_missing\n");
        if (log_fd >= 0) {
            fsync(log_fd);
        }
        sync();
        for (;;) {
            if (watchdog >= 0) {
                ioctl(watchdog, WDIOC_KEEPALIVE, 0);
            }
            sleep(5);
        }
    }

    log_text("android_starting\n");
    handoff_watchdog_to_kernel(&watchdog);
    /* /system is read-only erofs and has no gru-proc, gru-sys, or bootlog.
       SwitchRoot moves every mount onto it and fatals if the directory is
       missing. Detach while the log fd is still open, then close it.
       Nothing keeps reading kmsg after this. */
    log_err("detach_bootlog", umount2("/bootlog", MNT_DETACH) == 0 ? 0 : errno);
    log_err("detach_gru_proc", umount2("/gru-proc", MNT_DETACH) == 0 ? 0 : errno);
    log_err("detach_gru_sys", umount2("/gru-sys", MNT_DETACH) == 0 ? 0 : errno);
    if (log_fd >= 0) {
        fsync(log_fd);
        close(log_fd);
        log_fd = -1;
    }
    if (kmsg >= 0) {
        close(kmsg);
        kmsg = -1;
    }
    sync();
    argv[0] = "/init.android";
    execv("/init.android", argv);
    log_fd = open(LOG_PATH, O_WRONLY | O_APPEND | O_SYNC, 0644);
    log_text("exec_init_android_failed\n");
    if (log_fd >= 0) {
        fsync(log_fd);
    }
    sync();
    for (;;) {
        sleep(30);
    }
    (void)argc;
}
