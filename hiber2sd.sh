#!/bin/bash
#
# История версий
# -------------------------------------------------------------------------------------------------------
# Версия 2.1 почищены комментарии, удалены отладочные заметки 
# Версия 2.2 Переписывает конфигурацию для гибернации даже если она уже существует
# Версия 2.3 Скрипт завершиться при ошибке в любой команде
# Версия 2.4 Произведена структуризация скрипта комментариями
# Версия 2.5 Исключена ненужная переконфигурация initramfs при удалении настроек гибернации
# Версия 2.6 Скрипт проверяет запускался ли он ранее и остались ли настройки
# -------------------------------------------------------------------------------------------------------
# Конец истории версий
#
# введение и пояснения для юзера
# -------------------------------------------------------------------------------------------------------
set -e
echo "Если  на  комьпютере  файловая  система  ext4, то этот скрипт позволяет без"
echo "перезагрузки ввести систему в гибернацию на диск даже если она не настроена."
echo "Предварительно     необходимо   установить   пакет   uswsusp-git   из   AUR."
echo "Не  выходя  из  скрипта,  установи  этот  пакет  в новом окне терминала так:"
echo "------------------------>  pamac build uswsusp-git  <-----------------------"
echo "После  этого  скрипт  произведет  настройку  системы и предложит гибернацию."
echo "Существующие   настройки  swap не повредятся, только добавится  необходимое."
echo "Если  гибернация  более  не  нужна, скрипт  удалит  настройки  и  swap-файл."
echo "Если настройки гибернации удалены вручную, удалите файл /etc/mkif."
# -------------------------------------------------------------------------------------------------------
# Разъяснения юзерам сделаны
#
# Удаление некоторых ненужных настроек гибернации в случае, если она больше не нужна
# -------------------------------------------------------------------------------------------------------
echo -e "\n"; read -n 1 -p "Удалить настройки гибернации, сделанные этим скриптом? [y/N]: " delhib;
if [[ "$delhib" = [yYlLдД] ]]; then echo -e "\n"; 
  if [ -e /etc/mkif ]; 
    then
      if [ -e /swapfile ]; then swapoff /swapfile ; rm -f /swapfile ; fi
      cp -v /etc/fstab /etc/fstab.backup
      if grep -q 'swapfile none swap defaults' /etc/fstab; then sed -i '/swapfile none swap defaults/d' /etc/fstab; fi
      cp -v /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
      mki=0
      if grep -q 'uresume' /etc/mkinitcpio.conf; 
        then sed -i 's!\(^HOOKS.*udev\) \(uresume\) \(.*filesystems.*\)!\1 \3!' /etc/mkinitcpio.conf; mki=1 ;
        else echo -e "\n"; echo "/etc/mkinitcpio.conf уже не содержит хук uresume"; echo -e "\n";
      fi
      if [ -e /etc/suspend.conf ]; then
        cp -v /etc/suspend.conf /etc/suspend.conf.backup
        if grep -q 'resume device' /etc/suspend.conf; then sed -i '/resume device/d' /etc/suspend.conf; mki=1 ; fi
        if grep -q 'resume offset' /etc/suspend.conf; then sed -i '/resume offset/d' /etc/suspend.conf; mki=1 ; fi
      fi
      if [[ $mki = 1 ]]; then mkinitcpio -P ; fi
      rm -f /etc/mkif ;
    else echo -e "\n"; echo "Настройки скриптом не производились! Ваши настройки удалите руками"; echo -e "\n";
  fi
fi
# -------------------------------------------------------------------------------------------------------
# Конец процедуры удаления настроек гибернации
#
# Настройка гибернации в файл
# -------------------------------------------------------------------------------------------------------
echo -e "\n" ; read -n 1 -p "Попытаться гибернизировать? [y/N]: " hib ;
if [[ "$hib" = [yYlLдД] ]]; 
  then echo -e "\n" ; 
    # Скрипт работает только на ext4
    tipfs="$(df -Th | grep "$(df | grep '/$' | awk '{ print $1 }')" | awk '{ print $2 }')"
    if [[ ! $tipfs = ext4 ]]; then echo "Ты странный какой-то, у тебя файловая система не ext4"; set +e ; sleep 10; exit; fi
    # для нормальной работы скрипта необходим пакет uswsusp-git
    package="uswsusp-git"; check="$(pacman -Qs --color always "${package}" | grep "local" | grep "${package}")";
    if [ -n "${check}" ] ; 
      then
      # Проверка запускался ли скрипт ранее
      if [ -e /etc/mkif ]; 
        then echo -e "\n"; echo "Настройки скриптом уже производились!"; echo -e "\n";
        # создание файла подкачки 
        # -------------------------------------------------------------------------------------------------------
        else if [ -e /swapfile ]; then swapoff /swapfile ; rm -f /swapfile ; fi
          echo -e "\n" ; echo -e "Создание и настройка файла подкачки /swapfile"; echo -e "\n"
          ozu="$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 "K" }')"
          fallocate -l $ozu /swapfile ; chmod 600 /swapfile ; mkswap /swapfile ; 
          # Определяем поддержку TRIM
          ssd="$(lsblk -D | grep $(lsblk -r | grep '/$' | awk '{ print $1 }') | awk '{ print $4 }')"; 
          if [[ "$ssd" = 0B ]]; then swapon /swapfile; else swapon --discard /swapfile; fi
          cp -v /etc/fstab /etc/fstab.backup
          if grep -q 'swapfile none swap' /etc/fstab; then sed -i '/swapfile none swap/d' /etc/fstab; fi
          if [[ "$ssd" = 0B ]]; 
            then echo "/swapfile none swap defaults 0 0" | tee -a /etc/fstab; 
            else echo "/swapfile none swap defaults,discard 0 0" | tee -a /etc/fstab; 
          fi
          # -------------------------------------------------------------------------------------------------------
          # файл подкачки создан
          #
          # Настройка initramfs
          # -------------------------------------------------------------------------------------------------------
          echo -e "\n" ; echo -e "Настройка initramfs"; echo -e "\n"
          cp -v /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
          if grep -q 'uresume' /etc/mkinitcpio.conf; 
            then echo "/etc/mkinitcpio.conf уже содержит хук uresume"; 
            else sed -i 's!\(^HOOKS.*udev\) \(.*filesystems.*\)!\1 uresume \2!' /etc/mkinitcpio.conf;
          fi
          if [ -e /etc/suspend.conf ]; 
            then cp -v /etc/suspend.conf /etc/suspend.conf.backup
              if grep -q 'resume device' /etc/suspend.conf; then sed -i '/resume device/d' /etc/suspend.conf; fi
              if grep -q 'resume offset' /etc/suspend.conf; then sed -i '/resume offset/d' /etc/suspend.conf; fi
              df /swapfile | grep dev | awk '{ print "resume device = " $1 }' | tee -a /etc/suspend.conf
              swap-offset /swapfile | tee -a /etc/suspend.conf
            else df /swapfile | grep dev | awk '{ print "resume device = " $1 }' | tee /etc/suspend.conf
              swap-offset /swapfile | tee -a /etc/suspend.conf
          fi
          mkinitcpio -P ; 
          echo "Файл /etc/mkif создан скриптом hiber2sd и указывает на признак существования настроек скрипта" | tee /etc/mkif;
          echo "suspend on" | tee -a /etc/mkif;
      fi
      # -------------------------------------------------------------------------------------------------------
      # Настройка initramfs выполнена
      #
      # Настройка параметров гибернации пакета uswsusp-git
      # -------------------------------------------------------------------------------------------------------
      echo -e "\n" ; echo -e "Настройка параметров гибернации пакета uswsusp-git"; echo -e "\n" 
      if [ -f /etc/systemd/system/systemd-hibernate.service.d/override.conf ]; 
        then rm -f /etc/systemd/system/systemd-hibernate.service.d/override.conf ; 
      fi
      mkdir -p /etc/systemd/system/systemd-hibernate.service.d 
      # if [ ! -d "$DIR" ]; then mkdir $DIR ; fi
      echo "[Service]" | tee /etc/systemd/system/systemd-hibernate.service.d/override.conf
      echo "ExecStart=" | tee -a /etc/systemd/system/systemd-hibernate.service.d/override.conf
      echo "ExecStartPre=-/usr/bin/run-parts -v -a pre /usr/lib/systemd/systemd-sleep" | tee -a /etc/systemd/system/systemd-hibernate.service.d/override.conf
      echo "ExecStart=/usr/bin/s2disk" | tee -a /etc/systemd/system/systemd-hibernate.service.d/override.conf
      echo "ExecStartPost=-/usr/bin/run-parts -v --reverse -a post /usr/lib/systemd/systemd-sleep" | tee -a /etc/systemd/system/systemd-hibernate.service.d/override.conf
      echo " " | tee -a /etc/systemd/system/systemd-hibernate.service.d/override.conf
      # Настройка параметра гибернации системы на диск с полным отключением питания
      if [ -f /etc/systemd/sleep.conf.d/hibernatemode.conf ]; then rm -f /etc/systemd/sleep.conf.d/hibernatemode.conf ; fi
      mkdir -p /etc/systemd/sleep.conf.d
      echo "[Sleep]" | tee /etc/systemd/sleep.conf.d/hibernatemode.conf
      echo "HibernateMode=shutdown" | tee -a /etc/systemd/sleep.conf.d/hibernatemode.conf
      echo " " | tee -a /etc/systemd/sleep.conf.d/hibernatemode.conf
      # -------------------------------------------------------------------------------------------------------
      # Настройка конфигов для гибернации на диск выполнена
      #
      # гибернация на диск
      # -------------------------------------------------------------------------------------------------------
      echo -e "\n" ; read -n 1 -p "Гибернизируемся? [y/N]: " hiber;
      if [[ "$hiber" = [yYlLдД] ]]; 
        then echo -e "\n" ; systemctl hibernate; 
        # -------------------------------------------------------------------------------------------------------
        # гибернация на диск произведена
        else echo -e "\n" ; echo -e "Теперь можно использовать штатную гибернацию или повторно запустить этот скрипт"; echo -e "\n" 
      fi
      #
      # Пост комментарии для юзера
      # -------------------------------------------------------------------------------------------------------
      # Пакет uswsusp-git из AUR не установлен, обработка для гибернации не сделана
      else echo -e "\n" ; echo "Для работы скрипта надо установить пакет uswsusp-git из AUR!"; echo -e "\n" ;
    fi
  else echo -e "\n" ; echo "Ну на нет и суда нет! Если ошибся, то запусти скрипт снова!" ; echo -e "\n" ;
  # -------------------------------------------------------------------------------------------------------
  # Окончание работы скрипта, восстановление стандартных параметров оболочки
  #
fi
set +e 
