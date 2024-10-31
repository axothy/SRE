package ru.axothy.utils;

import java.io.BufferedInputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.File;
import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;

public class Utils {
    public static void extractTar(String tarFile, String dest) throws IOException {
        File destFile = new File(dest);
        if (!destFile.exists()) {
            destFile.mkdirs();
        }

        try (FileInputStream fis = new FileInputStream(tarFile);
             BufferedInputStream bis = new BufferedInputStream(fis);
             TarArchiveInputStream tarIn = new TarArchiveInputStream(bis)) {

            TarArchiveEntry entry;

            while ((entry = tarIn.getNextTarEntry()) != null) {
                File destPath = new File(dest, entry.getName());
                if (entry.isDirectory()) {
                    if (!destPath.exists()) {
                        destPath.mkdirs();
                    }
                } else {
                    File parent = destPath.getParentFile();
                    if (!parent.exists()) {
                        parent.mkdirs();
                    }
                    try (FileOutputStream fout = new FileOutputStream(destPath)) {
                        byte[] buffer = new byte[4096];
                        int len;
                        while ((len = tarIn.read(buffer)) != -1) {
                            fout.write(buffer, 0, len);
                        }
                    }
                }
            }
        }
    }
}

