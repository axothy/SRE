# Домашнее задание 4

## 1. Скрипт, получающий информацию о CPU

Написать скрипт, получающий информацию о CPU: количество cpu, модель, рабочая/максимальная частота, количество ядер/потоков, размер кэшей; а также о физической памяти: количество, тип и размер плашек, какие слоты они заним ают.

Для получения доступа к железу была использована утилита dmidecode
Для получения информации о cpu воспользовался утилитой lscpu. 
Ниже на скриншоте представлен вывод для моей VPS

![img1](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img1.png)


## 2. hugepages

Настроить использование обычных hugepages (размер 2 мб), смонтировать их в какой-либо раздел, написать программу, которая создает memory mapped file (аллоцировать несколько страниц) и запишет в него произвольное данные (любое слово). Убедиться, что страницы и правда задействованы. Проверить наличие файла в смонтированном разделе, прочитать данные из него из консоли штатными средствами.

У меня размер hugepages составляет 2048 кБ (2 МБ) (по умаолчанию), проверил через команду grep Huge /proc/meminfo.
Вывод на скриншоте ниже:

![img2](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img2.png)

Зарезервировал 10 hugepages: sudo sysctl -w vm.nr_hugepages=10,
в /etc/sysctl.conf добавил vm.nr_hugepages=10,
применил настройки sudo sysctl -p

На скрине ниже видно теперь что их 10 и они свободны:

![img3](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img3.png)

Далее смонтировал hugepages

sudo mkdir /mnt/huge

sudo mount -t hugetlbfs none /mnt/huge

Решил написать программу на Java которая будет создавать файл в /mnt/huge, устанавливать его размер на несколько мб, отображать файл в память (memory mapped file). ну и записывать что-то в память

Программу написал, скомпилил и запустил, скриншот ниже: 

![img4](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img4.png)

Видим выше вывод нашей программы об успешной записи в memory-mapped файл. 

Теперь введем снвоа команду grep Huge /proc/meminfo чтобы проверить уменьшилось ли количество hugepages свободных, вывод на скриншоте ниже:

![img5](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img5.png)

Теперь убедимся и проверим какие файлы открыты в /mnt/huge:

ls -l /mnt/huge
  
Вывод команды на скриншоте ниже

![img6](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img6.png)

Можем прочитать данные из файла при помощи hexdump -C /mnt/huge/testfile | head

![img7](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img7.png)

Или например при помощи strings /mnt/huge/testfile

![img8](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img8.png)

## 3. Запуск процесса с привязкой к одному ядру

Запустить процесс с привязкой к одному ядру (процесс должен потреблять 100% ядра). Сменить ему политику на realtime FIFO, разрешив потреблять не более 75% процессорного времени. Запустить на этом же ядре вторую копию процесса с любой обычной политикой, убедиться, что он может выполняться и потребляет оставшееся ему время cpu.

Сделал программу потребляющую cpu:

```Java
public class CpuBurn {
    public static void main(String[] args) {
        while (true) {
        }
    }
}
```

Выполнил компиляцию при помощи javac.

Запустим наш Java-процесс, привязав его к первому ядру (ядро 0), и установим политику планирования SCHED_FIFO с приоритетом 50

sudo taskset -c 0 chrt -f 50 java CpuBurn

И также запустим вторую копию этого жава процесса с обычной политикой планирования, привязанную к тому же ядру

taskset -c 0 java CpuBurn

Теперь выполним топ и увидим что у нас есть два джава процесса которые заняли cpu, один на 75 другой на 25 процентов

Вывод команды топ на скрине ниже

![img11](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img11.png)

Таким образом мы запустили на этом же ядре вторую копию процесса с любой обычной политикой, убеделиись, что он может выполняться и потребляет оставшееся ему время cpu.


## 4. raid1 массив

Создайте программный raid1 массив и добавьте в него hot spare диск. Проверьте, что все работает. Для этого надо “сломать“ один из дисков массива и убедиться, что запустился ребилд на резервный диск.

![img12](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img12.png)

• /dev/loop0 — диск1

• /dev/loop1 — диск2

• /dev/loop2 — резервный диск

Создаем raid1 массив из двух основных дисков и одного горячего резервного.

`sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 /dev/loop0 /dev/loop1 --spare-devices=1 /dev/loop2`

![img13](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img13.png)

Создаем файловую систему на новом raid-массиве и монтируем его

sudo mkfs.ext4 /dev/md0

sudo mkdir /mnt/raid

sudo mount /dev/md0 /mnt/raid

Теперь проверим что все работает введем команду sudo touch /mnt/raid/testfile

а потом команду ls /mnt/raid

Вывод на скрине ниже

![img14](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img14.png)

### Симуляция отказа

Откажем /dev/loop1 след образом:

sudo mdadm /dev/md0 --fail /dev/loop1

sudo mdadm /dev/md0 --remove /dev/loop1

![img15](/Users/axothy/IdeaProjects/SRE/homework4/results/imgs/img15.png)

Что важно увидеть на скрине выше: горячий резервный диск /dev/loop2 автоматически вошел в состав массива
(данный вывод команды отличается от того что я делал до отказа, просто забыл заскринить). 



