import java.io.RandomAccessFile;
import java.nio.channels.FileChannel;
import java.nio.MappedByteBuffer;

public class HugePageTest {
    public static void main(String[] args) {
        String filename = "/mnt/huge/testfile";
        int fileSize = 10 * 1024 * 1024; // 10 МБ

        try (RandomAccessFile file = new RandomAccessFile(filename, "rw");
             FileChannel channel = file.getChannel()) {
            file.setLength(fileSize);

            MappedByteBuffer buffer = channel.map(FileChannel.MapMode.READ_WRITE, 0, fileSize);

            String data = "This is HugePages";
            buffer.put(data.getBytes("UTF-8"));

            System.out.println("Данные записаны в memory-mapped файл.");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
