
#!/bin/sh
# Copyright by Dasandata.co.ltd
# http://www.dasandata.co.kr
# Ver : 2210

# Variables
VENDOR=$(dmidecode | grep -i manufacturer | awk '{print$2}' | head -1)
NIC=$(ip a | grep 'state UP' | cut -d ":" -f 2 | tr -d ' ')
OSCHECK=$(cat /etc/os-release | grep ^ID= | cut -d "=" -f 2 | tr -d '"')

# CUDA version check
if [ ! -f /root/cudaversion.txt ]; then
  echo "Linux_Automatic_Script Install Start (Ver: 2210)" | tee -a /root/install_log.txt
  case $OSCHECK in 
    rocky )
      echo "Select CUDA Version for Rocky Linux:" | tee -a /root/install_log.txt
      select CUDAV in "11-0" "11-1" "11-2" "11-3" "11-4" "11-5" "12-0" "12-1" "No-GPU"; do
        echo "Selected CUDA Version: $CUDAV" | tee -a /root/install_log.txt
        echo $CUDAV > /root/cudaversion.txt
        break
      done
    ;;
    ubuntu )
      OSVER=$(lsb_release -rs | tr -d '.')
      case $OSVER in
        2004|2204)
          select CUDAV in "11-0" "11-1" "11-2" "11-3" "11-4" "11-5" "12-0" "12-1" "No-GPU"; do
            echo "Selected CUDA Version: $CUDAV" | tee -a /root/install_log.txt
            echo $CUDAV > /root/cudaversion.txt
            break
          done
        ;;
      esac
    ;;
  esac
  echo "CUDA Version Select complete" | tee -a /root/install_log.txt
fi

# rc.local setup
if [ ! -f /root/log_err.txt ]; then
  touch /root/log_err.txt
  echo "rc.local Setting start" | tee -a /root/install_log.txt
  case $OSCHECK in
    rocky )
      echo "Setting up rc.local for Rocky Linux" | tee -a /root/install_log.txt
      echo "bash /root/LAS/Linux_Auto_Script.sh" >> /etc/rc.d/rc.local
      chmod +x /etc/rc.d/rc.local
      systemctl enable rc-local.service
    ;;
    ubuntu )
      echo "Setting up rc.local for Ubuntu" | tee -a /root/install_log.txt
      echo -e '#!/bin/sh -e
exit 0' > /etc/rc.local
      echo "bash /root/LAS/Linux_Auto_Script.sh" >> /etc/rc.local
      chmod +x /etc/rc.local
      systemctl restart rc-local.service
    ;;
  esac
  echo "rc.local setting complete" | tee -a /root/install_log.txt
else
  echo "rc.local already set up." | tee -a /root/install_log.txt
fi

# Further configurations...

