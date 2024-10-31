package ru.axothy.utils;

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.Path;

public class CgroupUtils {
    private static final String CGROUP_ROOT = "/sys/fs/cgroup";

    public static void setMemoryLimit(String groupName, long bytes) throws IOException {
        Path memoryCgroupPath = Paths.get(CGROUP_ROOT, groupName);
        Files.createDirectories(memoryCgroupPath);

        try (FileWriter writer = new FileWriter(memoryCgroupPath.resolve("memory.max").toFile())) {
            writer.write(Long.toString(bytes));
        }
    }

    public static void setCpuLimit(String groupName, double cpuShares) throws IOException {
        Path cpuCgroupPath = Paths.get(CGROUP_ROOT, groupName);
        Files.createDirectories(cpuCgroupPath);

        // Пример для 1 CPU (100% одного ядра)
        // Команда выглядит так
        // echo "100000 100000" > /sys/fs/cgroup/mydocker-<таймстемп>/cpu.max
        // Это означает, что  cgroup может использовать 100000 микросекунд CPU в течение 100000 микросекунд
        // что эквивалентно 100% одного ядра.
        String cpuMax = (int)(cpuShares * 100000) + " 100000";
        try (FileWriter writer = new FileWriter(cpuCgroupPath.resolve("cpu.max").toFile())) {
            writer.write(cpuMax);
        }
    }

    public static void addPidToCgroup(String groupName, int pid) throws IOException {
        Path cgroupPath = Paths.get(CGROUP_ROOT, groupName);
        Path cgroupProcs = cgroupPath.resolve("cgroup.procs");

        // Записываем PID в файл cgroup.procs
        try (FileWriter writer = new FileWriter(cgroupProcs.toFile(), true)) {
            writer.write(pid + System.lineSeparator());
        }
    }
}
