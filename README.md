# hiber2sd

Скрипт проверялся на manjaro Talos 22.1.2 Ядро: 6.3.3-1-MANJARO Xfce

Если  на  комьпютере  файловая  система  ext4, то этот скрипт позволяет без
перезагрузки ввести систему в гибернацию на диск даже если она не настроена.

Предварительно     необходимо   установить   пакет   uswsusp-git   из   AUR.

Не  выходя  из  скрипта,  установи  этот  пакет  в новом окне терминала так:

------------------------>  pamac build uswsusp-git  <-----------------------

После  этого  скрипт  произведет  настройку  системы и предложит гибернацию.

Существующие   настройки  swap не повредятся, только добавится  необходимое.

Если  гибернация  более  не  нужна, скрипт  удалит  настройки  и  swap-файл.

Скрипт проверяет запускался ли он ранее и остались ли настройки.