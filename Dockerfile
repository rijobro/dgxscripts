# Base image
ARG DOCKER_BASE
FROM $DOCKER_BASE


################################################################################
# Install misc required packages
################################################################################
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y \
    openssh-server nano sudo htop ffmpeg libsm6 libxext6 \
    gdb valgrind firefox x264 libx264-dev

################################################################################
# Create user, assign to groups, set password, switch to new user
################################################################################
ARG UNAME
ARG PWD_HASH
ARG USER_ID
ARG GROUP_ID
ARG GROUPS
ARG GIDS
RUN addgroup --gid ${GROUP_ID} ${UNAME}
RUN adduser --ingroup ${UNAME} --system --shell /bin/bash --uid ${USER_ID} ${UNAME}
RUN _groups=($GROUPS) && _gids=($GIDS) && \
    for ((i=0; i<${#_groups[@]}; ++i)); do \
        group=${_groups[$i]} && \
        gid=${_gids[$i]} && \
        addgroup --gid $gid $group && \
        usermod -a -G $group $UNAME; \
    done
RUN printf "root:%s" "$PWD_HASH" | chpasswd -e
RUN printf "${UNAME}:%s" "$PWD_HASH" | chpasswd -e
RUN adduser ${UNAME} sudo

RUN touch /var/run/motd.new

# Change to user
WORKDIR /home/${UNAME}
USER ${UNAME}
RUN mkdir ~/Documents ~/Documents/Code


################################################################################
# Set paths
################################################################################
ENV PATH "/home/${UNAME}/.local/bin:$PATH"
RUN echo "export HOME=/home/${UNAME}" >> ~/.bashrc
RUN echo "export PATH=/home/${UNAME}/.local/bin:$PATH" >> ~/.bashrc
RUN echo "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> ~/.bashrc
RUN echo "source /home/${UNAME}/.bashrc" >> ~/.bash_profile
# Misc bash
RUN echo "export TERM=xterm" >> ~/.bashrc
RUN echo "export DEBUGPY_EXCEPTION_FILTER_USER_UNHANDLED=1" >> ~/.bashrc
# Colourful bash
RUN echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\]'" >> ~/.bashrc


################################################################################
# Github credentials
################################################################################
ARG GITHUB_NAME
ARG GITHUB_EMAIL
RUN git config --global user.name ${GITHUB_NAME}
RUN git config --global user.email ${GITHUB_EMAIL}


################################################################################
# Jupyter password
################################################################################
ARG JUPY_PWD_HASH
RUN jupyter notebook --generate-config
RUN echo "c.NotebookApp.password = '${JUPY_PWD_HASH}'" >> ~/.jupyter/jupyter_notebook_config.py


################################################################################
# Custom bashrc additions
################################################################################
RUN cd ~/Documents/Code/ && git clone https://github.com/rijobro/bash_profile.git
RUN echo "source /home/${UNAME}/Documents/Code/bash_profile/rich_bashrc.sh" >> ~/.bashrc


################################################################################
# Set up SSHD to be run as non-sudo user
################################################################################
RUN mkdir -p ~/.ssh && \
	ssh-keygen -f ~/.ssh/id_rsa -N '' -t rsa && \
    ssh-keygen -f ~/.ssh/id_dsa -N '' -t dsa

RUN echo "PasswordAuthentication yes" >> ~/.ssh/sshd_config && \
    echo "Port 2222" >> ~/.ssh/sshd_config && \
    echo "HostKey ~/.ssh/id_rsa" >> ~/.ssh/sshd_config && \
    echo "HostKey ~/.ssh/id_dsa" >> ~/.ssh/sshd_config && \
    echo "AuthorizedKeysFile  ~/.ssh/authorized_keys" >> ~/.ssh/sshd_config && \
    echo "ChallengeResponseAuthentication no" >> ~/.ssh/sshd_config && \
    echo "UsePAM no" >> ~/.ssh/sshd_config && \
    echo "Subsystem sftp /usr/lib/ssh/sftp-server" >> ~/.ssh/sshd_config && \
    echo "PidFile ~/.ssh/sshd.pid" >> ~/.ssh/sshd_config && \
    echo "PrintMotd no" >> ~/.ssh/sshd_config

# merge authorized keys and id_rsa. Latter means you can connect from machine that
# created the container, and the former means you can connect from all the places
# that can connect to that machine.
COPY authorized_keys .
COPY id_rsa.pub .
RUN paste -d "\n" authorized_keys id_rsa.pub > ~/.ssh/authorized_keys
RUN rm authorized_keys id_rsa.pub

EXPOSE 2222


################################################################################
# Pip install requirements and set up jupyter notebook
################################################################################
USER root
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements.txt
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/requirements-dev.txt
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/MONAI/master/docs/requirements.txt
RUN python -m pip install --upgrade -r https://raw.githubusercontent.com/Project-MONAI/tutorials/master/requirements.txt
RUN python -m pip install --upgrade ipywidgets torchsummary scikit-learn jupyterthemes
RUN conda install -c conda-forge moviepy tensorboardx
USER ${UNAME}

# Set up jupyter notebook, w/ blue or green theme
RUN jt -t oceans16 -T -N
#RUN jt -t monokai -f fira -fs 13 -nf ptsans -nfs 11 -N -kl -cursw 5 -cursc r -cellw 95% -T


################################################################################
# Clear apt install cache
################################################################################
USER root
RUN rm -rf /var/lib/apt/lists/*
USER ${UNAME}
