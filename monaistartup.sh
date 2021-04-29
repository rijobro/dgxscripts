#!/bin/bash


################################################################################
# Usage
################################################################################
print_usage()
{
	# Display Help
	echo 'Script to be run at start of docker job.'
	echo
	echo 'Syntax: monaistartup.sh [-h|--help] [--compile_monai] [--jupy] [--ssh_server]'
	echo '                        [--pulse_audio] [--python_path val] '
	echo
	echo 'options:'
	echo '-h, --help          : Print this help.'
	echo
	echo '--compile_monai     : Compile MONAI code.'
	echo '--jupy              : Start a jupyter notebook'
	echo '--ssh_server        : Start an SSH server.'
	echo '--pulse_audio       : Use pulseaudio to send audio back to local machine.'
	echo
	echo '--python_path       : Extra elements to be prepended to PYTHONPATH'
	echo '                      (multiple elements can be colon separated).'
	echo
}

################################################################################
# parse input arguments
################################################################################
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-h|--help)
			print_usage
			exit 0
		;;
		--compile_monai)
			compile_monai=true
		;;
		--jupy)
			jupy=true
		;;
		--ssh_server)
			ssh_server=true
		;;
		--pulse_audio)
			pulse_audio=true
		;;
		--python_path)
			python_path=$2
			shift
		;;
		*)
			print_usage
			exit 1
		;;
	esac
	shift
done

# Default variables
: ${compile_monai:=false}
: ${jupy:=false}
: ${ssh_server:=false}
: ${pulse_audio:=false}

echo
echo
echo "Compile MONAI: ${compile_monai}"
echo "Start jupyter session: ${jupy}"
echo "SSH server: ${ssh_server}"
echo "Pulseaudio (send audio to local): ${pulse_audio}"
echo
echo "Prepend to PYTHONPATH: ${python_path}"
echo
echo

set -e # exit on error
set -x # print command before doing it

source ~/.bashrc

# Append to PYTHONPATH
if [[ -v python_path ]]; then
	export PYTHONPATH="${python_path}:$PYTHONPATH"
	printf "export PYTHONPATH=%s\n" "$PYTHONPATH" >> ~/.bashrc
fi

# Compile MONAI cuda code
if [ "$compile_monai" = true ]; then
	cd ~/Documents/Code/MONAI
	BUILD_MONAI=1 python setup.py develop
fi

# SSH server
if [ "$ssh_server" = true ]; then
	nohup /usr/sbin/sshd -D -f ~/.ssh/sshd_config -E ~/.ssh/sshd.log &
fi

# Pulseaudio (send audio back to local terminal)
if [ "$pulse_audio" = true ]; then
	pulseaudio --start
fi

# Jupyter notebook
if [ "$jupy" = true ]; then
	nohup jupyter notebook --ip 0.0.0.0 --no-browser --notebook-dir="~" > ~/.jupyter_notebook.log 2>&1
fi

sleep infinity
