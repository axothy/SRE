package ru.axothy;

import org.apache.commons.io.FilenameUtils;
import ru.axothy.utils.CgroupUtils;
import ru.axothy.utils.NSUtils;
import ru.axothy.utils.Utils;

import java.io.File;
import java.io.IOException;


public class MiniDocker {
    private static String memLimit = "100M";
    private static double cpuLimit = 1.0;
    private static String rootfs = "rootfs.tar";
    private static String command = "/bin/bash";
    private static final String CGROUP_DEFAULT_NAME = "mydocker";

    public static void main(String[] args) {
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--mem":
                    memLimit = args[++i];
                    break;
                case "--cpu":
                    cpuLimit = Double.parseDouble(args[++i]);
                    break;
                case "--root":
                    rootfs = args[++i];
                    break;
                default:
                    command = args[i];
                    break;
            }
        }

        try {
            // 1. Создание неймспейсов
            NSUtils.unshareNamespaces();

            // 2. Настройка cgroups
            long timestamp = System.currentTimeMillis();
            String cgroupName = CGROUP_DEFAULT_NAME + "-" + timestamp;

            CgroupUtils.setMemoryLimit(cgroupName, parseMemory(memLimit));
            CgroupUtils.setCpuLimit(cgroupName, cpuLimit);
            int pid = getPid();
            CgroupUtils.addPidToCgroup(cgroupName, pid);

            // 3. Изменение root файловой системы
            // Распаковываем .tar
            Utils.extractTar(rootfs, "/tmp/mydocker/" + cgroupName + "/rootfs");
            NSUtils.changeRoot("/tmp/mydocker/" + cgroupName + "/rootfs");

            // 4. Запуск команды
            System.out.println("ZAPUSKAEM");


            ProcessBuilder processBuilder = new ProcessBuilder("sh", "-c", command);
            processBuilder.directory(new File(System.getProperty("user.dir")));

            Process process = processBuilder.start();
            int exitCode = process.waitFor();

            System.out.println("Process exited with code: " + exitCode);
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static long parseMemory(String memLimit) {
        if (memLimit.endsWith("M") || memLimit.endsWith("m")) {
            return Long.parseLong(memLimit.replaceAll("[Mm]", "")) * 1024 * 1024;
        } else if (memLimit.endsWith("G") || memLimit.endsWith("g")) {
            return Long.parseLong(memLimit.replaceAll("[Gg]", "")) * 1024 * 1024 * 1024;
        } else if (memLimit.endsWith("K") || memLimit.endsWith("k")) {
            return Long.parseLong(memLimit.replaceAll("[Kk]", "")) * 1024;
        } else {
            return Long.parseLong(memLimit);
        }
    }

    private static int getPid() {
        String pid = java.lang.management.ManagementFactory.getRuntimeMXBean().getName().split("@")[0];
        return Integer.parseInt(pid);
    }
}
