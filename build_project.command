#!/bin/zsh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/desktop"
APP_LINK="$PROJECT_DIR/DBSCAN-Visualizer.app"

cd "$PROJECT_DIR"

if ! command -v cmake >/dev/null 2>&1; then
    QT_CMAKE="$HOME/Qt/Tools/CMake/CMake.app/Contents/bin/cmake"

    if [ -x "$QT_CMAKE" ]; then
        CMAKE="$QT_CMAKE"
    else
        echo "CMake не найден."
        echo "Установите CMake или откройте проект через Qt Creator."
        exit 1
    fi
else
    CMAKE="cmake"
fi

if [ -z "$CMAKE_PREFIX_PATH" ]; then
    for candidate in "$HOME"/Qt/6*/macos(N); do
        if [ -d "$candidate/lib/cmake/Qt6" ]; then
            export CMAKE_PREFIX_PATH="$candidate"
        fi
    done
fi

echo "Сборка проекта DBSCAN..."
"$CMAKE" -S "$PROJECT_DIR" -B "$BUILD_DIR"
"$CMAKE" --build "$BUILD_DIR"

APP_PATH="$BUILD_DIR/appDBSCAN.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Приложение не найдено: $APP_PATH"
    echo "Проверьте, что сборка завершилась без ошибок."
    exit 1
fi

ln -sfn "$APP_PATH" "$APP_LINK"

echo ""
echo "Готово."
echo "Приложение можно открыть здесь:"
echo "$APP_LINK"
