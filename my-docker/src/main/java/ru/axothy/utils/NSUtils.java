package ru.axothy.utils;

import com.sun.jna.Library;
import com.sun.jna.Native;

public class NSUtils {
    public interface CLibrary extends Library {
        CLibrary INSTANCE = Native.load("c", CLibrary.class);

        int unshare(int flags);

        int chroot(String path);

        int setgid(int gid);

        int setuid(int uid);

        int mount(String source, String target, String filesystemtype, long mountflags, String data);

        int umount(String target);

        int pivot_root(String new_root, String put_old);

        int sethostname(String name, int len);
    }

    public static final int CLONE_NEWNS = 0x00020000; // Mount namespace
    public static final int CLONE_NEWPID = 0x20000000; // PID namespace

    public static void unshareNamespaces() {
        int flags = CLONE_NEWNS | CLONE_NEWPID;
        int result = CLibrary.INSTANCE.unshare(flags);
        if (result != 0) {
            throw new RuntimeException("Failed to unshare namespaces: " + Native.getLastError());
        }
    }

    public static void changeRoot(String newRoot) {
        int result;

        result = CLibrary.INSTANCE.mount("proc", "/proc", "proc", 0, null);
        if (result != 0) {
            throw new RuntimeException("Failed to mount /proc: " + Native.getLastError());
        }

        // Выполняем chroot
        result = CLibrary.INSTANCE.chroot(newRoot);
        if (result != 0) {
            throw new RuntimeException("Failed to chroot: " + Native.getLastError());
        }

        // Меняем текущий каталог на "/"
        System.setProperty("user.dir", "/");
    }
}

