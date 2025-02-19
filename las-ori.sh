#!/bin/sh
# Copyright by Dasandata.co.ltd
# http://www.dasandata.co.kr
# Ver : 2209

# 1. 변수 선언
## Dell or Supermicro 확인
VENDOR=$(dmidecode | grep -i manufacturer | awk '{print$2}' | head -1)
## Network Interface
NIC=$(ip a | grep 'state UP' | cut -d ":" -f 2 | tr -d ' ')
## centos, ubuntu 구별 변수 선언
OSCHECK=$(cat /etc/os-release | head -1 | cut -d "=" -f 2 | tr -d "\"" | awk '{print$1}' | tr '[A-Z]' '[a-z]')

## CUDA 버전 선택 후 파일에 저장
ls /root/cudaversion.txt &> /dev/null
if [ $? != 0 ]
then
  echo "You have run Linux_Automatic_Script" | tee -a /root/install_log.txt
  echo "Copyright by Dasandata.co.ltd" | tee -a /root/install_log.txt
  echo "http://www.dasandata.co.kr" | tee -a /root/install_log.txt
  echo "" | tee -a /root/install_log.txt
  echo "Linux_Automatic_Script Install Start (Ver: 2209)" | tee -a /root/install_log.txt
  echo "" | tee -a /root/install_log.txt
  echo "CUDA Version Select" | tee -a /root/install_log.txt
  case $OSCHECK in 
    rocky )
      until [ $CUDAV != ' ' ]
      do
        PS3='Please Select one : '
        select CUDAV in 11-8 12-4 12-6 No-GPU; do echo "Select CUDA Version : $CUDAV" ; break; done
      done 
      echo $CUDAV > /root/cudaversion.txt
      echo "" | tee -a /root/install_log.txt
      echo "Cuda Version Select complete" | tee -a /root/install_log.txt
    ;;
     ubuntu )
      OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')
      case $OS in
        ubuntu2404|ubuntu2204|ubuntu2004|ubuntu1804 )
          until [ $CUDAV != ' ' ]
          do
            PS3='Please Select one : '
            select CUDAV in 11-8 12-4 12-6 No-GPU; do echo "Select CUDA Version : $CUDAV" ; break; done
          done 
          echo $CUDAV > /root/cudaversion.txt
          echo "" | tee -a /root/install_log.txt
          echo "Cuda Version Select complete" | tee -a /root/install_log.txt
          ;;
        *)
          echo "Unsupported Ubuntu version: $OS" | tee -a /root/install_log.txt
          ;;
      esac
    ;;
    *)
    ;;

  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "CUDA Version select is already" | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 2. rc.local 생성 및 변경
ls /root/log_err.txt &> /dev/null
if [ $? != 0 ]
then
  ## 에러를 저장할 파일 생성
  touch /root/log_err.txt
  echo "" | tee -a /root/install_log.txt
  echo "rc.local Setting start" | tee -a /root/install_log.txt
  case $OSCHECK in
    centos | rocky )
      ## centos는 이미 rc.local이 존재하여 실행될 파일값만 넣어준다.
      chmod +x /etc/rc.d/rc.local
      systemctl enable rc-local.service
      sed -i '13a bash /root/LAS/Linux_Auto_Script.sh' /etc/rc.d/rc.local
      echo "rc.local setting complete" | tee -a /root/install_log.txt
    ;;
    ubuntu )
      OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')
      sleep 3
      ## Ubuntu16만 이미 rc.local이 존재하여 나눠서 작업
      if [ $OS = "ubuntu1604" ]
      then
        sed -i '13a bash /root/LAS/Linux_Auto_Script.sh' /etc/rc.local
      else
        echo -e  '#!/bin/sh -e \nexit 0' | tee -a /etc/rc.local
        chmod +x /etc/rc.local
        systemctl restart rc-local.service >> /root/install_log.txt 2>> /root/log_err.txt
        systemctl status rc-local.service >> /root/install_log.txt 2>> /root/log_err.txt
        sed -i '1a bash /root/LAS/Linux_Auto_Script.sh' /etc/rc.local
        echo "" | tee -a /root/install_log.txt
        echo "rc.local setting complete" | tee -a /root/install_log.txt
      fi
    ;;
    *)
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "The rc.local file already exists." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 3. nouveau 끄기 및 grub 설정
cat /etc/default/grub | grep ipv6.disable &> /dev/null
if [ $? = 1 ]
then
  echo "" | tee -a /root/install_log.txt
  echo "Nouveau Disable and Grub Settings Start." | tee -a /root/install_log.txt
  case $OSCHECK in
    rocky )
      echo "" | tee -a /root/install_log.txt
      echo "Rocky Linux Grub Setting Start for Rocky Linux $OSCHECK." | tee -a /root/install_log.txt
      sed -i  's/rhgb quiet//' /etc/default/grub
      sed -i  's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /' /etc/default/grub
      echo "blacklist nouveau" >>         /etc/modprobe.d/blacklist.conf
      echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist.conf
      dracut  -f >> /root/install_log.txt 2>> /root/log_err.txt

      if [ "$OSCHECK" = "rocky8" ]; then
        sed -i  '/IPV6/d' /etc/sysconfig/network-scripts/ifcfg-${NIC}
        grub2-mkconfig -o /boot/grub2/grub.cfg >> /root/install_log.txt 2>> /root/log_err.txt
        grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg  >> /root/install_log.txt 2>> /root/log_err.txt
      elif [ "$OSCHECK" = "rocky9" ]; then
        # Rocky Linux 9 specific network and GRUB settings
        sed -i '/^\[ipv6\]$/,+3d' /etc/NetworkManager/system-connections/${NIC}.nmconnection
        grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg  >> /root/install_log.txt 2>> /root/log_err.txt
      fi

      echo "" | tee -a /root/install_log.txt
      echo "Nouveau and Grub Settings complete for Rocky Linux $OSCHECK." | tee -a /root/install_log.txt
    ;;
    ubuntu )
      OSCHECK=$(cat /etc/os-release | head -1 | cut -d "=" -f 2 | tr -d "\"" | awk '{print$1}' | tr '[A-Z]' '[a-z]')
      OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')
      echo "" | tee -a /root/install_log.txt
      echo "$OS Grub Setting Start." | tee -a /root/install_log.txt
      systemctl set-default  multi-user.target >> /root/install_log.txt 2>> /root/log_err.txt
      echo "blacklist nouveau"         >> /etc/modprobe.d/blacklist.conf
      echo "options nouveau modeset=0" >> /etc/modprobe.d/blacklist.conf
      perl -pi -e 's/splash//' /etc/default/grub
      perl -pi -e 's/quiet//'  /etc/default/grub
      perl -pi -e  's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="ipv6.disable=1 /'  /etc/default/grub
      perl -pi -e  's/^GRUB_HIDDEN_TIMEOUT=/#GRUB_HIDDEN_TIMEOUT=/'                /etc/default/grub
      update-initramfs -u && update-grub2 >> /root/install_log.txt 2>> /root/log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Nouveau and Grub Setting complete" | tee -a /root/install_log.txt
    ;;
    *)
      echo "" | tee -a /root/install_log.txt
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "Nouveau Disable and Grub Settings has already been complete." | tee -a /root/install_log.txt
fi

# ubuntu 2204/2404 cloud-init 제거
case $OS in
  ubuntu2204 | ubuntu2404)
    echo "cloud-init remove on $OS."  | tee -a /root/install_log.txt
    echo 'datasource_list: [ None ]' |  tee /etc/cloud/cloud.cfg.d/90_dpkg.cfg
    apt-get -y purge cloud-init      | tee -a /root/install_log.txt
    rm -rf /etc/cloud/  /var/lib/cloud/
esac


echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 4. selinux 제거 및 저장소 변경
case $OSCHECK in
   rocky )
    OS=$(cat /etc/redhat-release | awk '{print$1,$4}' | cut -d "." -f 1 | tr -d " " | tr '[A-Z]' '[a-z]')
    echo "" | tee -a /root/install_log.txt
    echo "OS is $OS" | tee -a /root/install_log.txt
    ## SELINUX Disabled 작업
    SELINUX=$(getenforce)
    if [ $SELINUX = "Disabled" ]
    then
      echo "" | tee -a /root/install_log.txt
      echo "SELINUX is already turned off." | tee -a /root/install_log.txt
    else
      echo "" | tee -a /root/install_log.txt
      echo "Changed SELINUX to disabled." | tee -a /root/install_log.txt
      setenforce 0
      sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    fi
  ;;
  ubuntu1604|ubuntu1804|ubuntu2004|ubuntu2204|ubuntu2404 )
    OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')
    echo "" | tee -a /root/install_log.txt
    echo "OS is $OS" | tee -a /root/install_log.txt
    echo "" | tee -a /root/install_log.txt
    echo "Repository Change" | tee -a /root/install_log.txt+9
    if [ "$OS" = "ubuntu2404" ]; then
      # Use the new file path for Ubuntu 24.04
      perl -pi -e 's/kr.archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list.d/ubuntu.sources
      perl -pi -e 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list.d/ubuntu.sources
    else
      # Use the old file path for Ubuntu 22.04
      perl -pi -e 's/kr.archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
      perl -pi -e 's/security.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list
    fi
    echo "" | tee -a /root/install_log.txt
    cat /etc/apt/sources.list | grep -v "#\|^$" >> /root/install_log.txt
    ;;
  *)
    echo "" | tee -a /root/install_log.txt
    echo "OS Check is Failed" | tee -a /root/install_log.txt
    ;;
esac

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt
# 5. 기본 패키지 설치
case $OS in
  rocky8 | rocky9 )
    echo "" | tee -a /root/install_log.txt
    echo "$OS Package Install" | tee -a /root/install_log.txt
    ## Package 설치를 ipmi 여부로 Server와 PC를 나눠서 진행
    rpm -qa | grep -i htop &> /dev/null
    if [ $? != 0 ]
    then
      yum -y update >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      yum install -y epel-release >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      yum install -y rdate                                                                             >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum install -y ethtool pciutils openssh mlocate nfs-utils xauth firefox nautilus wget bind-utils >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum install -y tcsh tree lshw tmux kernel-headers kernel-devel gcc make gcc-c++ yum-utils       >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum install -y cmake dstat perl perl-CPAN perl-core net-tools openssl-devel git-lfs vim         >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum install -y git bash-completion smartmontools                                                >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      dmidecode | grep -i ipmi &> /dev/null
      if [ $? = 0 ]
      then
        yum install -y ipmitool >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      else
        echo "" | tee -a /root/install_log.txt
        echo "PC,Workstation do not install ipmitool" | tee -a /root/install_log.txt
      fi
      echo ""
      if [ $OS = "centos7" ]
      then
        yum -y groupinstall "GNOME Desktop" >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        yum install -y glibc-static yum-plugin-priorities >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      else
        yum -y groupinstall "Server with GUI" >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      fi
      yum -y groupinstall "Graphical Administration Tools" >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum -y groups install "Development Tools" >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum install -y glibc-devel libstdc++ libstdc++-devel >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      sed -i -e "s/\]$/\]\npriority=5/g" /etc/yum.repos.d/epel.repo >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      yum install -y htop ntfs-3g snapd figlet >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "The package install complete" | tee -a /root/install_log.txt
    else
      echo "" | tee -a /root/install_log.txt
      echo "The package has already been installed." | tee -a /root/install_log.txt
    fi
    #불필요한 서비스 disable
    systemctl disable iscsi.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable ksm.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable ksmtuned.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable libstoragemgmt.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable libvirtd.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable spice-vdagentd.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable vmtoolsd.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable ModemManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable cups.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    systemctl disable cups-browsed.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    if [ $OS = "centos7" ]
    then
      systemctl disable NetworkManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl stop    NetworkManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable NetworkManager-dispatcher.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable NetworkManager-wait-online.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
    else
      echo "" | tee -a /root/install_log.txt
    fi
  ;;
  ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2404)
    echo "" | tee -a /root/install_log.txt
    echo "$OS Package Install" | tee -a /root/install_log.txt
    ## Package 설치를 ipmi 여부로 Server와 PC를 나눠서 진행
    dpkg -l | grep -i htop &> /dev/null
    if [ $? != 0 ]
    then
      apt-get update >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      apt-get -y install vim nfs-common rdate xauth firefox gcc make tmux wget figlet >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      apt-get -y install net-tools xfsprogs ntfs-3g aptitude dstat curl python mlocate >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      apt-get -y install ubuntu-desktop dconf-editor gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      apt-get -y install libzmq3-dev libxml2-dev snapd lvm2 ethtool htop dnsutils >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      DEBIAN_FRONTEND=noninteractive apt-get install -y smartmontools >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      #불필요한 서비스 disable
      systemctl disable bluetooth.service      >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable iscsi.service          >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable ksm.service            >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable ksmtuned.service       >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable libstoragemgmt.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable libvirtd.service       >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable spice-vdagentd.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable vmtoolsd.service       >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable ModemManager.service   >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable cups.service           >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable cups-browsed.service   >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 3
      ## ipmi 여부로 PC, Server 판단
      dmidecode | grep -i ipmi &> /dev/null
      if [ $? = 0 ]
      then
        apt-get -y install ipmitool >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl disable NetworkManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl stop    NetworkManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl disable NetworkManager-dispatcher.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl disable NetworkManager-wait-online.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      else
        echo "" | tee -a /root/install_log.txt
        echo "PC,Workstation do not install ipmitool" | tee -a /root/install_log.txt
      fi
      echo "" | tee -a /root/install_log.txt
      echo "The package install complete" | tee -a /root/install_log.txt
    else
      echo "" | tee -a /root/install_log.txt
      echo "The package has already been installed." | tee -a /root/install_log.txt
    fi
  ;;
  ubuntu2204 )
    echo "" | tee -a /root/install_log.txt
    echo "$OS Package Install" | tee -a /root/install_log.txt
    ## Package 설치를 ipmi 여부로 Server와 PC를 나눠서 진행
    dpkg -l | grep -i rdate &> /dev/null
    if [ $? != 0 ]
    then
      apt-get update >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      apt-get -y install vim nfs-common xauth firefox gcc make tmux wget figlet net-tools >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      apt-get -y install xfsprogs ntfs-3g aptitude lvm2 dstat curl npm locate  >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      apt-get -y install dconf-editor gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      apt-get -y install libzmq3-dev libcurl4-openssl-dev libxml2-dev snapd ethtool htop dnsutils >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 2
      apt-get install -y smartmontools  >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      apt-get install -y ubuntu-desktop >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      apt-get install -y rdate >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      #불필요한 서비스 disable
      systemctl disable bluetooth.service      >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable iscsi.service          >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable spice-vdagentd.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable vmtoolsd.service       >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable ModemManager.service   >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable cups.service           >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      systemctl disable cups-browsed.service   >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      sleep 3
      ## ipmi 여부로 PC, Server 판단
      dmidecode | grep -i ipmi &> /dev/null
      if [ $? = 0 ]
      then
        apt-get -y install ipmitool >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl disable NetworkManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl stop    NetworkManager.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl disable NetworkManager-dispatcher.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
        systemctl disable NetworkManager-wait-online.service >> /root/Package_install_log.txt 2>> /root/Package_install_log_err.txt
      else
        echo "" | tee -a /root/install_log.txt
        echo "PC,Workstation do not install ipmitool" | tee -a /root/install_log.txt
      fi
      echo "" | tee -a /root/install_log.txt
      echo "The package install complete" | tee -a /root/install_log.txt
    else
      echo "" | tee -a /root/install_log.txt
      echo "The package has already been installed." | tee -a /root/install_log.txt
    fi
  ;;
  *)
  echo "" | tee -a /root/install_log.txt
  echo "Package install has already been complete" | tee -a /root/install_log.txt
  ;;
esac

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 6. 프로필 설정 
cat /etc/profile | grep Dasandata &> /dev/null
if [ $? != 0 ]
  then
    echo "" | tee -a /root/install_log.txt
    echo "Profile Settings Start" | tee -a /root/install_log.txt
    # 프로필 alias및 프롬프트 설정 시작
    echo " "  >> /etc/profile
    echo "# Add by Dasandata"  >>   /etc/profile
    echo "alias vi='vim' "  >>   /etc/profile
    echo "alias ls='ls --color=auto' "  >>   /etc/profile
    echo "alias ll='ls -lh' "  >>   /etc/profile
    echo "alias grep='grep --color=auto' "  >>   /etc/profile
    echo " "  >> /etc/profile
    echo "# Add Timestamp to .bash_history "  >> /etc/profile
    echo 'export HISTTIMEFORMAT="20%y/%m/%d %T "'  >> /etc/profile
    echo "export PS1='\[\e[1;46;30m\][\u@\h:\W]\\$\[\e[m\] '"  >> /root/.bashrc
    # echo "export PS1='\[\e[1;47;30m\][\u@\h:\W]\\$\[\e[m\] '"  >> /home/sonic/.bashrc
    echo "export PS1='\[\e[1;47;30m\][\u@\h:\W]\\$\[\e[m\] '"  >> /home/kds/.bashrc
    source  /etc/profile
    source  /root/.bashrc
    echo $HISTSIZE >> /root/install_log.txt 2>> /root/log_err.txt
    echo "" | tee -a /root/install_log.txt
    echo "Profile Settings complete" | tee -a /root/install_log.txt
  else
    echo "" | tee -a /root/install_log.txt
    echo "Profile settings are already set up." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 7. 서버 시간 동기화

if [ $OS = "rocky8" ]
then
  yum install -y chrony >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  sed -i 's/pool 2.pool.ntp.org iburst/pool kr.pool.ntp.org iburst/' /etc/chrony.conf 
  systemctl enable chronyd >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  systemctl start  chronyd >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  chronyc sources >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  timedatectl >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  clock --systohc >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  date >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  hwclock >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
else
  echo "Start time setting" | tee -a /root/install_log.txt
  rdate  -s  time.bora.net >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  hwclock --systohc >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  date >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  hwclock >> /root/Time_Setting_log.txt 2>> /root/Time_Setting_log_err.txt
  echo "" | tee -a /root/install_log.txt
  echo "Time setting completed" | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 8. 파이썬 설치
pip3 -V &> /dev/null
if [ $? != 0 ]
then
  case $OS in
    centos7 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Install" | tee -a /root/install_log.txt
      yum -y install python-devel python-setuptools python-setuptools-devel >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      curl -O https://bootstrap.pypa.io/pip/2.7/get-pip.py >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      python get-pip.py >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      yum -y install python36  python36-devel python36-pip python36-setuptools >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      easy_install-3.6   pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      yum -y install openblas* >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip   install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip3   install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      perl -pi -e 's/python3/python/'   /usr/local/bin/pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Install complete" | tee -a /root/install_log.txt
    ;;
    rocky8 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Install" | tee -a /root/install_log.txt
      yum -y install python36-devel >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Install complete" | tee -a /root/install_log.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install" | tee -a /root/install_log.txt
      python3 -m pip install --upgrade pip >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      python3 -m pip install numpy scipy nose matplotlib pandas keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #python3 -m pip install --upgrade tensorflow-gpu==1.13.1 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      python3 -m pip install --upgrade tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      python3 -m pip install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1604 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Install" | tee -a /root/install_log.txt
      apt-get -y install python-dev python3-dev libssl-dev build-essential libffi-dev >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      curl -fsSL -o- https://bootstrap.pypa.io/pip/2.7/get-pip.py | python2.7 >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      curl -fsSL -o- https://bootstrap.pypa.io/pip/3.5/get-pip.py | python3.5 >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip   install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip3   install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      perl -pi -e 's/python3/python/'   /usr/local/bin/pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1804 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Install" | tee -a /root/install_log.txt
      apt-get -y install  python-pip python3-pip python-tk python3-tk >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip3 install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      perl -pi -e 's/python3/python/'   /usr/local/bin/pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2004 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Install" | tee -a /root/install_log.txt
      apt-get -y install python3-pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      add-apt-repository universe >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      apt update >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      apt list --upgradeable >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      apt install -y python2 >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      python2.7 get-pip.py --force-reinstall >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip3 install --upgrade pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      perl -pi -e 's/python3/python/'   /usr/local/bin/pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2204 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Install" | tee -a /root/install_log.txt
      apt-get -y install python3-pip >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      pip3 install --upgrade pip     >> /root/Python_install_log.txt 2>> /root/Python_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Install complete" | tee -a /root/install_log.txt
    ;;
    *)
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "The python has already been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 9. 파이썬 패키지 설치
pip3 list | grep tensor &> /dev/null 
if [ $? != 0 ]
then
  case $OS in
    centos7 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install" | tee -a /root/install_log.txt
      pip install  numpy   scipy  nose  matplotlib  pandas  keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip uninstall --yes dnspython >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      yum erase -y python-ldap pyparsing >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install  numpy   scipy  nose  matplotlib  pandas  keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip install --upgrade setuptools >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      rm -rf /usr/share/doc/python-enum34-1.0.4* >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      rm -rf /usr/lib/python2.7/site-packages/enum34-1.0.4-py2.7.egg-info >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip  install --upgrade setuptools==40 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip3 install --upgrade tensorflow-gpu==1.13.1 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade setuptools >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip  install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade optimuspyspark >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1604 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install" | tee -a /root/install_log.txt
      pip2 install  numpy   scipy  nose  matplotlib  pandas  keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install  numpy   scipy  nose  matplotlib  pandas  keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip2 install  --upgrade tensorflow-gpu==1.13.1 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip3 install  --upgrade tensorflow-gpu==1.13.1 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip2 install  --upgrade tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install  --upgrade tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip2 install  --upgrade setuptools >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install  --upgrade setuptools >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade optimuspyspark  >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade testresources >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip2 install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      sed -i 's/python.5/python2.7/g' /usr/local/bin/pip 
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1804 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install" | tee -a /root/install_log.txt
      pip install  numpy   scipy  nose  matplotlib  pandas  keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install  numpy   scipy  nose  matplotlib  pandas  keras >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip install  --upgrade tensorflow-gpu==1.13.1 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip3 install  --upgrade tensorflow-gpu==1.13.1 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip install  --upgrade tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install  --upgrade tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade cryptography==3.3.2 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade optimuspyspark  >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade testresources >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2004 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install"
      pip install --upgrade numpy scipy  nose  matplotlib  pandas  keras tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip install --upgrade numpy scipy  nose  matplotlib  pandas  keras tensorflow-gpu >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip install scipy==1.2.2 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade numpy scipy nose matplotlib pandas keras tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip3 install --upgrade numpy scipy nose matplotlib pandas keras tensorflow-gpu    >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install numpy==1.20.3 h5py==2.10.0 cryptography==3.3.2 python-dateutil==2.8.2 >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip install --upgrade torch torchvision  >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2204 )
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install"
      pip3 install --upgrade numpy scipy nose matplotlib pandas keras h5py cryptography tensorflow >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      #pip3 install --upgrade numpy scipy nose matplotlib pandas keras h5py cryptography tensorflow-gpu  >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      pip3 install --upgrade torch torchvision >> /root/pip_install_log.txt 2>> /root/pip_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Python Package Install complete" | tee -a /root/install_log.txt
    ;;
    *)
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "Python Package has been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 10. 방화벽 설정
case $OS in
  centos7 | rocky8 )
    firewall-cmd --list-all | grep 7777 &> /dev/null
    if [ $? != 0 ]
    then
      echo "" | tee -a /root/install_log.txt
      echo "Firewall Settings" | tee -a /root/install_log.txt
      systemctl enable firewalld >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      systemctl restart firewalld >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      firewall-cmd --add-port=7777/tcp  --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ## R Server Port
      firewall-cmd --add-port=8787/tcp  --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ## jupyterHub Port
      firewall-cmd --add-port=8000/tcp  --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ## masquerade on
      firewall-cmd --add-masquerade --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ## remove service
      firewall-cmd --remove-service=dhcpv6-client  --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      firewall-cmd --remove-service=cockpit  --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      firewall-cmd --remove-service=ssh  --permanent >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      firewall-cmd --reload >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      sed -i  "s/#Port 22/Port 7777/g" /etc/ssh/sshd_config
      if [ $OS = "rocky8" ]
      then
        sed -i  "s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
      else
        sed -i  "s/#PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
      fi
      echo "AddressFamily inet" >> /etc/ssh/sshd_config
      systemctl restart sshd >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Firewall setting complete" | tee -a /root/install_log.txt
    else
      echo "" | tee -a /root/install_log.txt
      echo "The Firewall has already been started." | tee -a /root/install_log.txt
    fi
  ;;
  ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2204 )
    ufw status | grep inactive &> /dev/null
    if [ $? = 0 ]
    then
      echo "" | tee -a /root/install_log.txt
      echo "Firewall Settings" | tee -a /root/install_log.txt
      systemctl start ufw >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      systemctl enable ufw >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      yes | ufw enable >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ufw default deny >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ufw allow 22/tcp  >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ufw allow 7777/tcp  >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ## R Server port
      ufw allow 8787/tcp  >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      ## JupyterHub port
      ufw allow 8000/tcp >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
      if [ $OS = "ubuntu1604" ]
      then
        perl -pi -e "s/Port 22/Port 7777/g" /etc/ssh/sshd_config
      else
        perl -pi -e "s/#Port 22/Port 7777/g" /etc/ssh/sshd_config
      fi
      perl -pi -e "s/PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
      echo "AddressFamily inet" >> /etc/ssh/sshd_config
      systemctl restart sshd >> /root/firewall_setting_log.txt 2>> /root/firewall_setting_log_err.txt
    else
      echo "" | tee -a /root/install_log.txt
      echo "The Firewall has already been started." | tee -a /root/install_log.txt
    fi
  ;;
  *)
    echo "" | tee -a /root/install_log.txt
  ;;
esac

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

: << 'END'
# 11. 사용자 생성 테스트
ls /home/ | grep -i dasan &> /dev/null
if [ $? != 0 ]
then
  case $OS in
    centos7 | rocky8 )
      echo "" | tee -a /root/install_log.txt
      echo "User Add Start" | tee -a /root/install_log.txt
      useradd dasan >> /root/useradd_log.txt 2>> /root/useradd_log_err.txt
      usermod -aG wheel dasan >> /root/useradd_log.txt 2>> /root/useradd_log_err.txt
    ;;
    ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2204 )
      echo "" | tee -a /root/install_log.txt
      echo "User add Start" | tee -a /root/install_log.txt
      adduser --disabled-login --gecos "" dasan >> /root/useradd_log.txt 2>> /root/useradd_log_err.txt
      usermod -G sudo dasan >> /root/useradd_log.txt 2>> /root/useradd_log_err.txt
    ;;
    *)
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "User add has already been complete." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt
END

# 12. H/W 사양 체크
cat /root/HWcheck.txt &> /dev/null
if [ $? != 0 ]
then
  echo "===== H/W Check Start =====" | tee -a /root/install_log.txt
  touch /root/HWcheck.txt
  echo "=====  H/W Check Start =====" >> /root/HWcheck.txt
  echo "=====  System =====" >> /root/HWcheck.txt
  dmidecode --type system | grep -v "^$\|#\|SMBIOS\|Handle\|Not" >> /root/HWcheck.txt
  echo "===== CPU =====" >> /root/HWcheck.txt
  lscpu | grep -v "Flags\|NUMA" >> /root/HWcheck.txt
  echo "===== Memory Devices =====" >> /root/HWcheck.txt
  dmidecode --type 16 | grep -v "dmidecode\|SMBIOS\|Handle" >> /root/HWcheck.txt
  dmidecode --type memory | grep "Number Of Devices\|Size\|Locator\|Clock\|DDR\|Rank" | grep -v "No\|Unknown" >> /root/HWcheck.txt
  cat /proc/meminfo | grep MemTotal >> /root/HWcheck.txt
  free -h >> /root/HWcheck.txt
  echo "===== PCIe =====" >> /root/HWcheck.txt
  lspci | grep -i vga >> /root/HWcheck.txt
  lspci | grep -i nvidia >> /root/HWcheck.txt
  dmidecode | grep NIC >> /root/HWcheck.txt
  lspci | grep -i communication >> /root/HWcheck.txt
  dmesg | grep NIC >> /root/HWcheck.txt
  echo "===== Power Supply =====" >> /root/HWcheck.txt
  dmidecode --type 39  | grep "System\|Name:\|Capacity" >> /root/HWcheck.txt
  echo "===== Disk & Partition =====" >> /root/HWcheck.txt
  blkid >> /root/HWcheck.txt
  echo "===== OS release & kernel =====" >> /root/HWcheck.txt
  uname -a >> /root/HWcheck.txt
  echo "" | tee -a /root/install_log.txt
  echo "=====  H/W Check Complete ===== " | tee -a /root/install_log.txt
else
  echo "" | tee -a /root/install_log.txt
  echo "H/W check has already been completed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 10
echo "" | tee -a /root/install_log.txt

## CPU 버전 PC, Server 여기까지 (Dell 서버만 뒤에 메일 설정 진행)
lspci | grep -i nvidia &> /dev/null
if [ $? != 0 ]
then
  echo "" | tee -a /root/install_log.txt
  echo "Complete basic setup" | tee -a /root/install_log.txt
  case $OS in
    centos7 | rocky8 )
      dmidecode | grep -i ipmi &> /dev/null
      if [ $? != 0 ]
      then
        echo "" | tee -a /root/install_log.txt
        echo "End of CPU version LAS" | tee -a /root/install_log.txt
        sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.d/rc.local
        systemctl set-default graphical.target >> /root/install_log.txt 2>> /root/log_err.txt
        reboot
      else
        echo "" | tee -a /root/install_log.txt
        echo "The server version continues." | tee -a /root/install_log.txt
        cat /root/nvidia.txt &> /dev/null
        if [ $? != 0 ]
        then
          touch /root/nvidia.txt
          reboot
        else
          echo "" | tee -a /root/install_log.txt
        fi
      fi
    ;;
    ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2204 )
      dmidecode | grep -i ipmi &> /dev/null
      if [ $? != 0 ]
      then
        echo "" | tee -a /root/install_log.txt
        echo "End of CPU version LAS" | tee -a /root/install_log.txt
        if [ $OS = "ubuntu1604" ]
        then
          sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.local
        else
          sed -i '1a bash /root/LAS/Check_List.sh' /etc/rc.local
        fi
        systemctl set-default graphical.target >> /root/install_log.txt 2>> /root/log_err.txt
        reboot
      else
        echo "" | tee -a /root/install_log.txt
        echo "The server version continues." | tee -a /root/install_log.txt
        cat /root/nvidia.txt &> /dev/null
        if [ $? != 0 ]
        then
          touch /root/nvidia.txt
          reboot
        else
          echo "" | tee -a /root/install_log.txt
        fi
      fi
    ;;
    *)
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "GPU Settings Start." | tee -a /root/install_log.txt
  cat /root/nvidia.txt &> /dev/null
  if [ $? != 0 ]
  then
    touch /root/nvidia.txt
    reboot
  else
    echo "" | tee -a /root/install_log.txt
  fi
fi

sleep 3
 
cat /root/cudaversion.txt | grep No &> /dev/null
if [ $? = 0 ]
then
  OS="Skip this server as it has no GPU."
else
  echo ""
fi

# 13. CUDA,CUDNN Repo 설치
ls /usr/local/ | grep cuda &> /dev/null
if [ $? != 0 ]
then
  case $OS in
    centos7 )
      echo "" | tee -a /root/install_log.txt
      echo "CUDA,CUDNN REPO install Start" | tee -a /root/install_log.txt
      yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      wget https://developer.download.nvidia.com/compute/machine-learning/repos/rhel7/x86_64/nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      yum -y install nvidia-machine-learning-repo-rhel7-1.0.0-1.x86_64.rpm >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      yum --disablerepo="*" --enablerepo="cuda-rhel7-x86_64" list available >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      yum -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      yum -y install openmotif* >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "CUDA,CUDNN REPO install complete" | tee -a /root/install_log.txt
    ;;
    rocky8 )
      dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      wget https://developer.download.nvidia.com/compute/machine-learning/repos/rhel8/x86_64/nvidia-machine-learning-repo-rhel8-1.0.0-1.x86_64.rpm >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      yum -y install nvidia-machine-learning-repo-rhel8-1.0.0-1.x86_64.rpm >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      yum -y install libXi-devel mesa-libGLU-devel libXmu-devel libX11-devel freeglut-devel libXm* openmotif* >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
    ;;
    ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2204 )
      echo "" | tee -a /root/install_log.txt
      echo "CUDA,CUDNN REPO install Start" | tee -a /root/install_log.txt
      apt-get -y install sudo gnupg >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/"$OS"/x86_64/3bf863cc.pub" >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      sh -c 'echo "deb https://developer.download.nvidia.com/compute/cuda/repos/'$OS'/x86_64 /" > /etc/apt/sources.list.d/nvidia-cuda.list' >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      apt-get update >> /root/GPU_repo_log.txt 2>> /root/GPU_repo_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "CUDA,CUDNN REPO install complete" | tee -a /root/install_log.txt
    ;;
    *)
      echo "" | tee -a /root/install_log.txt
      echo "CUDA,CUDNN repo not install:$OS" | tee -a /root/install_log.txt
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "The Cuda REPO has already been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 14. CUDA 설치 및 PATH 설정
ls /usr/local/ | grep cuda >> /root/install_log.txt 2>> /root/log_err.txt
if [ $? != 0 ]
then
  CUDAV=$(cat /root/cudaversion.txt)
  if [ $CUDAV = "No-GPU" ]
  then
    echo "No-GPU not install cuda" >> /root/install_log.txt 2>> /root/log_err.txt
  else
    CUDAV="${CUDAV/-/.}"
    case $OS in
      centos7 | rocky8 )
        echo "CUDA $CUDAV install Start" | tee -a /root/install_log.txt
        cat /etc/profile | grep "ADD Cuda" >> /root/install_log.txt 2>> /root/log_err.txt
        if [ $? != 0 ]
        then
          echo " "  >> /etc/profile
          echo "### ADD Cuda $CUDAV PATH"  >> /etc/profile
          echo "export PATH=/usr/local/cuda-$CUDAV/bin:/usr/local/cuda-$CUDAV/include:\$PATH " >> /etc/profile
          echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH " >> /etc/profile
          echo "export CUDA_HOME=/usr/local/cuda-$CUDAV " >> /etc/profile
          echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV/include " >> /etc/profile
          cat /etc/profile | tail -6 >> /root/install_log.txt 2>> /root/log_err.txt
        else
          echo "" | tee -a /root/install_log.txt
        fi
        CUDAV="${CUDAV/./-}"
        sleep 1

        rpm --import http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/D42D0685.pub
        yum -y install kmod-nvidia-latest-dkms

        yum -y install cuda-$CUDAV >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        sleep 1
        nvidia-smi -pm 1 >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        systemctl enable nvidia-persistenced >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        sleep 1
        source /etc/profile
        sleep 1
        source /root/.bashrc
        sleep 1
        echo "" | tee -a /root/install_log.txt
        echo "CUDA $CUDAV install Start complete" | tee -a /root/install_log.txt
      ;;
      ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2204 )
        echo "CUDA $CUDAV install Start" | tee -a /root/install_log.txt
        cat /etc/profile | grep "ADD Cuda" >> /root/install_log.txt 2>> /root/log_err.txt
        if [ $? != 0 ]
        then
          echo " "  >> /etc/profile
          echo "### ADD Cuda $CUDAV PATH"  >> /etc/profile
          echo "export PATH=/usr/local/cuda-$CUDAV/bin:/usr/local/cuda-$CUDAV/include:\$PATH " >> /etc/profile
          echo "export LD_LIBRARY_PATH=/usr/local/cuda-$CUDAV/lib64:/usr/local/cuda/extras/CUPTI/:\$LD_LIBRARY_PATH " >> /etc/profile
          echo "export CUDA_HOME=/usr/local/cuda-$CUDAV " >> /etc/profile
          echo "export CUDA_INC_DIR=/usr/local/cuda-$CUDAV/include " >> /etc/profile
          cat /etc/profile | tail -6 >> /root/install_log.txt 2>> /root/log_err.txt
        else
          echo "" | tee -a /root/install_log.txt
        fi
        CUDAV="${CUDAV/./-}"
        sleep 1
        apt-get -y install cuda-$CUDAV >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        sleep 1
        nvidia-smi -pm 1 >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        systemctl enable nvidia-persistenced >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        source /etc/profile
        sleep 1
        source /root/.bashrc
        sleep 1
        echo "" | tee -a /root/install_log.txt
        echo "CUDA $CUDAV install Start complete" | tee -a /root/install_log.txt
      ;;
      *)
        echo "" | tee -a /root/install_log.txt
        echo "CUDA not install:$OS" | tee -a /root/install_log.txt
      ;;
    esac
  fi
else
  echo "" | tee -a /root/install_log.txt
  echo "The CUDA has already been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 15. CUDNN 설치 및 PATH 설정
updatedb
locate libcudnn  &> /dev/null
if [ $? != 0 ]
then
  case $OS in
    centos7 )
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install Start" | tee -a /root/install_log.txt
      if [[ $CUDAV == *11* ]]
      then
        yum -y install libcudnn8* >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        yum -y update >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      else
        yum -y install libcudnn7* >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        yum -y update >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      fi
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install complete" | tee -a /root/install_log.txt
    ;;
    rocky8 )
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install Start" | tee -a /root/install_log.txt
      yum -y install libcudnn8* >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      yum -y install libnccl*   >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1604 | ubuntu1804 )
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install Start" | tee -a /root/install_log.txt
      if [[ $CUDAV == *11* ]]
      then
        apt-get -y install libcudnn8*    >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        apt-get -y install libcublas-dev >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      else
        apt-get -y install libcudnn7*    >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
        apt-get -y install libcublas-dev >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      fi
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2004 | ubuntu2204)
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install Start" | tee -a /root/install_log.txt
      apt-get -y install nvidia-cuda-toolkit >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      apt-get -y install libcudnn8*          >> /root/cuda_cudnn_install_log.txt 2>> /root/cuda_cudnn_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "libcudnn Install complete" | tee -a /root/install_log.txt
    ;;
    *)
    echo "" | tee -a /root/install_log.txt
    echo "CUDNN, PATH Setting:$OS" | tee -a /root/install_log.txt
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "The CUDNN has already been installed." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

# 16. 딥러닝 패키지 설치(R,R Server, JupyterHub, Pycharm)
updatedb
locate rstudio  &> /dev/null
if [ $? != 0 ]
then
  case $OS in
    centos7 )
      echo "" | tee -a /root/install_log.txt
      echo "Deep Learnig Package Install Start" | tee -a /root/install_log.txt
      ## R,R-sutdio install
      yum -y install R >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      wget https://download2.rstudio.org/server/centos7/x86_64/rstudio-server-rhel-2022.02.0-443-x86_64.rpm  >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yum -y install rstudio-server-rhel-2022.02.0-443-x86_64.rpm >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      ## JupyterHub install
      pip3 install --upgrade jupyterhub jupyterlab notebook >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      wget https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-16.10.0-1nodesource.x86_64.rpm >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      wget https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-devel-16.10.0-1nodesource.x86_64.rpm >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      rpm -ivh nodejs-16.10.0-1nodesource.x86_64.rpm nodejs-devel-16.10.0-1nodesource.x86_64.rpm >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      npm install -g configurable-http-proxy >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Deep Learnig Package install complete"  | tee -a /root/install_log.txt
    ;;
    rocky8 )
      ## R,R-studio install
      dnf config-manager --set-enabled powertools >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yum -y install R >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yum install libcurl-devel libxml2-devel >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      wget https://download2.rstudio.org/server/rhel8/x86_64/rstudio-server-rhel-2022.02.0-443-x86_64.rpm  >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yum -y install rstudio-server-rhel-2022.02.0-443-x86_64.rpm  >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      ## jupyter install
      python3 -m pip install jupyterhub jupyterlab notebook >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      curl -sL https://rpm.nodesource.com/setup_16.x | sudo -E bash - >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      sed -i '/failover/d'  /etc/yum.repos.d/nodesource-el8.repo >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yum -y install nodejs >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      npm install -g configurable-http-proxy >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
    ;;
    ubuntu1604 | ubuntu1804 | ubuntu2004 )
      echo "" | tee -a /root/install_log.txt
      echo "Deep Learnig Package Install Start" | tee -a /root/install_log.txt
      ## R,R-studio Install
      apt-get -y install r-base >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      apt-get -y install gdebi-core >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.02.0-443-amd64.deb >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yes | gdebi rstudio-server-2022.02.0-443-amd64.deb >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      ## JupyterHub install
      pip3 install --upgrade jupyterhub jupyterlab notebook >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      curl -fsSL https://deb.nodesource.com/setup_16.x | bash - >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      apt-get -y install nodejs default-jre >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      npm install -g configurable-http-proxy >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      ## Pycharm install
      snap install pycharm-community --classic >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Deep Learnig Package install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2204 )
      echo "" | tee -a /root/install_log.txt
      echo "Deep Learnig Package Install Start" | tee -a /root/install_log.txt
      ## R,R-studio Install
      apt-get -y install r-base       >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      apt-get -y install gdebi-core   >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt

      wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb
      dpkg -i libssl1.1_1.1.0g-2ubuntu4_amd64.deb

      wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.07.1-554-amd64.deb >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      yes | gdebi rstudio-server-2022.07.1-554-amd64.deb >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      ## JupyterHub install
      pip3 install --upgrade jupyterhub jupyterlab notebook >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt

      apt-get -y purge nodejs libnode72

      curl -fsSL https://deb.nodesource.com/setup_16.x | bash - >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      apt-get -y install nodejs default-jre >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      npm install -g configurable-http-proxy >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      ## Pycharm install
      snap install pycharm-community --classic >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "Deep Learnig Package install complete" | tee -a /root/install_log.txt
    ;;
    *)
      echo "" | tee -a /root/install_log.txt
      echo "$OS"   | tee -a /root/install_log.txt
    ;;
  esac
  sleep 3
else
  echo "" | tee -a /root/install_log.txt
  echo "The Deep Learnig Package has already been installed." | tee -a /root/install_log.txt
fi

## jupyterhub 마무리 설정
cat /root/cudaversion.txt | grep No &> /dev/null
if [ $? != 0 ]
then
  ls /lib/systemd/system/ | grep jupyter &> /dev/null
  if [ $? != 0 ]
  then
    echo "" | tee -a /root/install_log.txt
    echo "JupyterHub Setting Files Copy" | tee -a /root/install_log.txt
    ## jupyterhub 설정값 변경
    mkdir /etc/jupyterhub
    jupyterhub --generate-config -f /etc/jupyterhub/jupyterhub_config.py >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt

      sed -i '625a c.JupyterHub.port = 8000'                        /etc/jupyterhub/jupyterhub_config.py
      sed -i '656a c.JupyterHub.proxy_class = 'jupyterhub.proxy.ConfigurableHTTPProxy'' /etc/jupyterhub/jupyterhub_config.py
      sed -i '1260a c.Authenticator.admin_users = {"kds"}'        /etc/jupyterhub/jupyterhub_config.py
      sed -i '976a c.Spawner.default_url = '/lab''                  /etc/jupyterhub/jupyterhub_config.py

      sed -i '1450a c.LocalAuthenticator.create_system_users = True' /etc/jupyterhub/jupyterhub_config.py
      sed -i '1451a c.Authenticator.add_user_cmd = ['adduser', '--force-badname', '-q', '--gecos', '""', '--disabled-password']' /etc/jupyterhub/jupyterhub_config.py

    ## jupyterhub service 설정 파일 복사
    mv /root/LAS/jupyterhub.service  /lib/systemd/system/
    mv /root/LAS/jupyterhub          /etc/init.d/

    chmod 777 /lib/systemd/system/jupyterhub.service >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
    chmod 755 /etc/init.d/jupyterhub                 >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt

    systemctl daemon-reload                          >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
    systemctl enable jupyterhub.service              >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt
    systemctl restart jupyterhub.service             >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt

    R CMD BATCH /root/LAS/r_jupyterhub.R             >> /root/DL_install_log.txt 2>> /root/DL_install_log_err.txt

    echo "" | tee -a /root/install_log.txt
    echo "JupyterHub Setting Files Copy Complete" | tee -a /root/install_log.txt
  else
    echo "JupyterHub Settings is already" | tee -a /root/install_log.txt
  fi
else
  echo "$OS" | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

#### Server만 아래 스크립트 진행 #####
dmidecode | grep -i ipmi &> /dev/null
if [ $? != 0 ]
then
  # rc.local 기본 값으로 변경
  echo "" | tee -a /root/install_log.txt
  echo "LAS install complete" | tee -a /root/install_log.txt
  case $OSCHECK in
    centos | rocky )
      sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.d/rc.local
      systemctl set-default graphical.target >> /root/install_log.txt 2>> /root/log_err.txt
    ;;
    ubuntu )
      OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')
      if [ $OS = "ubuntu1604" ]
      then
        sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.local
        systemctl set-default graphical.target >> /root/install_log.txt 2>> /root/log_err.txt
      else
        sed -i '1a bash /root/LAS/Check_List.sh' /etc/rc.local
        systemctl set-default graphical.target >> /root/install_log.txt 2>> /root/log_err.txt
      fi
    ;;
    *)
    ;;
  esac
  reboot
else
  echo "" | tee -a /root/install_log.txt
  echo "Server Package Install Start." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

## GPU 없는 서버가 여기까지 건너뛰기 위해 제거했던 OS 변수 입력
if [ $OSCHECK = "ubuntu" ]
then
  OS=$(lsb_release -isr |  tr -d "." | sed -e '{N;s/\n//}' | tr '[A-Z]' '[a-z]')
else
  OS=$(cat /etc/redhat-release | awk '{print$1,$4}' | cut -d "." -f 1 | tr -d " " | tr '[A-Z]' '[a-z]')
fi

# 17. 서버 전용 MSM 설치
ls /usr/local/ | grep Mega &> /dev/null
if [ $? != 0 ]
then
  case $OS in
    centos7 | rocky8 )
      echo "" | tee -a /root/install_log.txt
      echo "MSM install start" | tee -a /root/install_log.txt
      mkdir /tmp/raid_manager
      cd /tmp/raid_manager
      wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/17.05.00.02_Linux-64_MSM.gz >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      tar zxf 17.05.00.02_Linux-64_MSM.gz >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      cd /tmp/raid_manager/disk/ && ./install.csh -a >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt

      systemctl daemon-reload >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      systemctl enable vivaldiframeworkd.service >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      systemctl start vivaldiframeworkd.service >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      cd /root/
      echo "" | tee -a /root/install_log.txt
      echo "MSM install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1604 | ubuntu1804 | ubuntu2004 | ubuntu2204 )
      echo "" | tee -a /root/install_log.txt
      echo "MSM install start" | tee -a /root/install_log.txt
      mkdir /tmp/raid_manager
      cd /tmp/raid_manager
      wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/17.05.00.02_Linux-64_MSM.gz >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      tar zxf 17.05.00.02_Linux-64_MSM.gz >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      cd /tmp/raid_manager/disk/
      apt-get -y install alien >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      alien --scripts *.rpm >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      dpkg --install lib-utils2_1.00-9_all.deb >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      dpkg --install megaraid-storage-manager_17.05.00-3_all.deb >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      systemctl daemon-reload >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      systemctl start vivaldiframeworkd.service >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      systemctl enable vivaldiframeworkd.service >> /root/MSM_install_log.txt 2>> /root/MSM_install_log_err.txt
      cd /root/
      echo "" | tee -a /root/install_log.txt
      echo "MSM install complete" | tee -a /root/install_log.txt
    ;;
    *)
    ;;
  esac
else
  echo "" | tee -a /root/install_log.txt
  echo "MSM is ready or IPMI does not exist." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

## Dell Server를 제외한 Server는 여기까지 실행
echo $VENDOR | grep -i dell &> /dev/null
if [ $? != 0 ]
then
# rc.local 기본 값으로 변경
  echo "" | tee -a /root/install_log.txt
  echo "LAS install complete" | tee -a /root/install_log.txt
    case $OS in
      centos7 | rocky8 )
        sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.d/rc.local
        sleep 2
        systemctl set-default  multi-user.target
      ;;
      ubuntu1604 )
        sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.local
        sleep 2
        systemctl set-default  multi-user.target
      ;;
      ubuntu1804 | ubuntu2004 )
        sed -i '1a bash /root/LAS/Check_List.sh' /etc/rc.local
        sleep 2
        systemctl set-default  multi-user.target
      ;;
      *)
      ;;
  esac
  reboot
else
  echo "" | tee -a /root/install_log.txt
  echo "The Dell server only OMSA setup begins." | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

### 19. Dell 전용 OMSA설치
systemctl status dsm_om_connsvc &> /dev/null
if [ $? != 0 ]
then
  echo "" | tee -a /root/install_log.txt
  echo "OMSA install start" | tee -a /root/install_log.txt
  case $OS in
    centos7 | rocky8 )
      ## OMSA Port
      firewall-cmd --add-port=1311/tcp  --permanent >> /root/install_log.txt 2>> /root/log_err.txt
      firewall-cmd --reload >> /root/install_log.txt 2>> /root/log_err.txt
      perl -p -i -e '$.==20 and print "exclude = libsmbios smbios-utils-bin\n"' /etc/yum.repos.d/CentOS-Base.repo
      wget http://linux.dell.com/repo/hardware/dsu/bootstrap.cgi -O  ./dellomsainstall.sh >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      sed -i -e "s/enabled=1/enabled=0/g" ./dellomsainstall.sh 
      yes | bash ./dellomsainstall.sh >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      sleep 3
      rm -f ./dellomsainstall.sh >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      yum -y erase  tog-pegasus-libs >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      yum -y install --enablerepo=dell-system-update_dependent -y srvadmin-all openssl-devel >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl daemon-reload >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dataeng >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dataeng >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "OMSA install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1604 )
      ## OMSA port
      ufw allow 1311/tcp >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo 'deb http://linux.dell.com/repo/community/openmanage/940/xenial xenial main'  >  /etc/apt/sources.list.d/linux.dell.com.sources.list
      wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-key add 0x1285491434D8786F.asc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-get -y update >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-get -y install srvadmin-all >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl daemon-reload >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dataeng >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dataeng >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "OMSA install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu1804 )
      ## OMSA port
      ufw allow 1311/tcp >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo 'deb http://linux.dell.com/repo/community/openmanage/940/bionic bionic main'  > /etc/apt/sources.list.d/linux.dell.com.sources.list
      wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-key add 0x1285491434D8786F.asc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-get -y update >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-get -y install srvadmin-all >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      cd /usr/lib/x86_64-linux-gnu/ >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 libssl.so >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      cd /root/
      systemctl daemon-reload >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dataeng >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dataeng >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "OMSA install complete" | tee -a /root/install_log.txt
    ;;
    ubuntu2004 | ubuntu2204 )
      ## OMSA port
      ufw allow 1311/tcp >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo 'deb http://linux.dell.com/repo/community/openmanage/10300/focal focal main'  > /etc/apt/sources.list.d/linux.dell.com.sources.list
      wget http://linux.dell.com/repo/pgp_pubkeys/0x1285491434D8786F.asc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-key add 0x1285491434D8786F.asc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-get -y update >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      apt-get -y install srvadmin-all >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      cd /usr/lib/x86_64-linux-gnu/ >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      ln -s /usr/lib/x86_64-linux-gnu/libssl.so.1.1 libssl.so >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      cd /root/
      systemctl daemon-reload >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dsm_sa_datamgrd.service >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl enable dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dsm_sa_datamgrd.service >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      systemctl start dsm_om_connsvc >> /root/OMSA_install_log.txt 2>> /root/OMSA_install_log_err.txt
      echo "" | tee -a /root/install_log.txt
      echo "OMSA install complete" | tee -a /root/install_log.txt
    ;;
    *)
      echo "" | tee -a /root/install_log.txt
      echo "OMSA install error" | tee -a /root/install_log.txt
    ;;
  esac
else
  echo ""| tee -a /root/install_log.txt
  echo "The OMSA has already been setting" | tee -a /root/install_log.txt
fi

echo "" | tee -a /root/install_log.txt
sleep 3
echo "" | tee -a /root/install_log.txt

## 스크립트 완료 정리 후 재부팅
echo "" | tee -a /root/install_log.txt
echo "LAS install complete" | tee -a /root/install_log.txt
case $OS in
  centos7 | rocky8 )
    sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.d/rc.local
    systemctl set-default  multi-user.target | tee -a /root/install_log.txt
  ;;
  ubuntu1604 )
    sed -i '13a bash /root/LAS/Check_List.sh' /etc/rc.local
    systemctl set-default  multi-user.target | tee -a /root/install_log.txt
  ;;
  ubuntu1804 | ubuntu2004 | ubuntu2204 )
    sed -i '1a bash /root/LAS/Check_List.sh' /etc/rc.local
    systemctl set-default  multi-user.target | tee -a /root/install_log.txt
  ;;
  *)
  ;;
esac
  reboot
