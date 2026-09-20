#!/bin/sh

set -e

cd $(dirname $0)
. ./chromium-gost-env.sh

ADDITIONAL_DEPS="$CHROMIUM_PATH/chrome/installer/linux/rpm/additional_deps"
BACKUP="$ADDITIONAL_DEPS.bak"

# Если остался backup от предыдущего (жёстко убитого) запуска - восстановить
if [ -f "$BACKUP" ]; then
    mv -f "$BACKUP" "$ADDITIONAL_DEPS"
fi
# Функция восстановления измененных зависимостей, вызывается при любом выходе
restore_deps() {
    if [ -f "$BACKUP" ]; then
        mv -f "$BACKUP" "$ADDITIONAL_DEPS"
    fi
}
trap restore_deps EXIT INT TERM

cp -f "$ADDITIONAL_DEPS" "$BACKUP"
sed -i -E \
  's/\(libgtk-3\.so\.0\(\)\(64bit\) or libgtk-4\.so\.1\(\)\(64bit\)\)/libgtk-3.so.0()(64bit)/' \
  "$ADDITIONAL_DEPS"
sed -i -E \
  's/\(libcurl\.so\(\)\(64bit\) or libcurl-gnutls\.so\.4\(\)\(64bit\) or libcurl-nss\.so\.4\(\)\(64bit\) or libcurl\.so\.4\(\)\(64bit\)\)/libcurl.so.4()(64bit)/' \
  "$ADDITIONAL_DEPS"

# Проверка, что булевых зависимостей не осталось
if grep -qE '\(.*or.*\)' "$ADDITIONAL_DEPS"; then
    echo "Ошибка: в additional_deps остались булевы зависимости." >&2
    echo "Возможно, Google снова изменил формат файла." >&2
    exit 1
fi

cd $CHROMIUM_PATH
gn gen out/RELEASE --args="is_debug=false symbol_level=0 strip_debug_info=true is_official_build=true enable_linux_installer=true $CHROMIUM_FLAGS $CHROMIUM_PRIVATE_ARGS"
ninja -C out/RELEASE "chrome/installer/linux:stable_rpm"

cd $CHROMIUM_GOST_REPO/build_linux/
mv -f $CHROMIUM_PATH/out/RELEASE/chromium-gost-stable-${CHROMIUM_TAG}-1.x86_64.rpm chromium-gost-${CHROMIUM_TAG}-alt-linux-amd64.rpm
