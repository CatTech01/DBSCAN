# DBSCAN
Программа для визуализации алгоритма DBSCAN и кластерного анализа (ЕГЭ по информатике, задание 27) / Program for Visualizing the DBSCAN Algorithm and Cluster Analysis (Unified State Exam in Informatics, Task 27)

## Как собрать и открыть на macOS

1. Установите Qt 6 и CMake.
2. Откройте папку проекта.
3. Запустите файл `build_project.command` двойным кликом или из терминала:

```bash
./build_project.command
```

После сборки в папке проекта появится ярлык:

```text
DBSCAN-Visualizer.app
```

Его можно открыть двойным кликом.

Сама сборка находится внутри папки проекта:

```text
build/desktop
```

Готовый архив для macOS можно собрать командой:

```bash
cmake -S . -B build/macos-release -DCMAKE_BUILD_TYPE=Release
cmake --build build/macos-release --config Release
macdeployqt build/macos-release/appDBSCAN.app -qmldir=.
ditto -c -k --sequesterRsrc --keepParent build/macos-release/appDBSCAN.app DBSCAN-Visualizer-macOS.zip
```

## Как собрать и открыть на Windows

В исходном коде `.exe` файла нет. Он появляется только после сборки проекта на Windows или после скачивания готового архива из GitHub Actions.

### Вариант 1: через Qt Creator

1. Установите Qt 6 вместе с Qt Creator.
2. Откройте файл `CMakeLists.txt` через Qt Creator.
3. Выберите комплект сборки Qt 6.
4. Нажмите `Run` / `Запустить`.

### Вариант 2: через готовый скрипт

1. Установите Qt 6 и CMake.
2. Откройте папку проекта.
3. Запустите двойным кликом:

```text
build_project_windows.bat
```

После сборки приложение будет лежать в папке:

```text
build/windows
```

Файл приложения находится здесь:

```text
build/windows/Release/appDBSCAN.exe
```

Если такой папки нет, проверьте также:

```text
build/windows/appDBSCAN.exe
```

Если `.exe` не запускается двойным кликом, откройте проект через Qt Creator.

## Готовые сборки

Готовые сборки для macOS и Windows можно найти на GitHub во вкладке `Releases`.
Там лежат архивы:

```text
DBSCAN-Visualizer-macOS
DBSCAN-Visualizer-Windows
```

В Windows-архиве `.exe` лежит внутри распакованной папки. Запускайте его оттуда, не вытаскивая отдельно от остальных файлов.
