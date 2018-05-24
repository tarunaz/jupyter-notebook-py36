# (ideally) minimal pyspark/jupyter notebook

FROM tmehrarh/openshift-spark:py36-latest

USER root

## taken/adapted from jupyter dockerfiles
# Not essential, but wise to set the lang
# Note: Users with other languages should set this in their derivative image
ENV LANGUAGE=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONIOENCODING=UTF-8 \
    CONDA_DIR=/opt/conda \
    NB_USER=nbuser \
    NB_UID=1011 \
    NB_PYTHON_VER=3.6.3 \
    SPARK_HOME=/opt/spark \
    MINICONDA_VERSION=4.3.21 \
    HADOOP_HOME=/opt/hadoop-2.7.6 \	
    JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.171-8.b10.el7_5.x86_64/jre \
    PATH=/opt/conda/bin:/opt/hadoop-2.7.6/bin:/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.171-8.b10.el7_5.x86_64/jre/bin:$PATH

# TODO remove tini after docker 1.13.1

LABEL io.k8s.description="PySpark Jupyter Notebook." \
      io.k8s.display-name="PySpark Jupyter Notebook." \
      io.openshift.expose-services="8888:http,42000:http,42100:http"

# expose a port for the workers to connect back
EXPOSE 42000
# also expose a port for the block manager
EXPOSE 42100

RUN mkdir -p /opt/hadoop-2.7.6

COPY hadoop-2.7.6.tar.gz /tmp
RUN tar -xzvf /tmp/hadoop-2.7.6.tar.gz -C /opt \
    && rm -rf /tmp/hadoop-2.7.6.tar.gz

ADD fix-permissions.sh /usr/local/bin/fix-permissions.sh 
RUN chmod +x /usr/local/bin/fix-permissions.sh  \
    && cd /tmp \
    && curl -s -o Miniconda3.sh https://repo.continuum.io/miniconda/Miniconda3-4.3.21-Linux-x86_64.sh \
    && echo c1c15d3baba15bf50293ae963abef853 Miniconda3.sh | md5sum -c - \
    && bash Miniconda3.sh -b -p $CONDA_DIR \
    && rm -rf Miniconda3.sh \
    && export PATH=$CONDA_DIR/bin:$PATH \
    && $CONDA_DIR/bin/conda config --system --prepend channels conda-forge  \
    && $CONDA_DIR/bin/conda config --system --set auto_update_conda false  \
    && $CONDA_DIR/bin/conda config --system --set show_channel_urls true  \
    && $CONDA_DIR/bin/conda update --all --quiet --yes  \
    && $CONDA_DIR/bin/conda install -c conda-forge 'jupyterhub=0.8.1' \
    && $CONDA_DIR/bin/conda install --quiet --yes 'nomkl' jupyter 'notebook=5.4.1' \
        'jupyterlab=0.32.0*' \
        'matplotlib=2.0*' \
    && yum erase -y gcc gcc-c++ glibc-devel \
    && yum clean all -y \
    && rm -rf /var/cache/yum \
    && rm -rf /root/.npm \
    && rm -rf /root/.cache \
    && rm -rf /root/.config \
    && rm -rf /root/.local \
    && rm -rf /root/tmp \
    && $CONDA_DIR/bin/conda clean -tipsy \
    && $CONDA_DIR/bin/conda remove --quiet --yes --force qt pyqt \
    && jupyter nbextension enable --py widgetsnbextension --sys-prefix \
    && fix-permissions.sh $CONDA_DIR


RUN echo 'PS1="\u@\h:\w\\$ \[$(tput sgr0)\]"' >> /root/.bashrc \
    && chgrp root /etc/passwd \
    && chgrp -R root /opt \
    && chmod -R ug+rwx /opt \
    && useradd -m -s /bin/bash -N -u $NB_UID $NB_USER \
    && usermod -g root $NB_USER   


USER $NB_USER


# Python binary and source dependencies and Development tools

# Make the default PWD somewhere that the user can write. This is
# useful when connecting with 'oc run' and starting a 'spark-shell',
# which will likely try to create files and directories in PWD and
# error out if it cannot. 
# 
ENV HOME /home/$NB_USER
RUN mkdir $HOME/.jupyter \
    && fix-permissions.sh $HOME 


USER root

# IPython
EXPOSE 8888
WORKDIR $HOME

RUN mkdir /notebooks  \
    && mkdir -p $HOME/.jupyter \
    && echo "c.NotebookApp.ip = '*'" >> $HOME/.jupyter/jupyter_notebook_config.py \
    && echo "c.NotebookApp.open_browser = False" >> $HOME/.jupyter/jupyter_notebook_config.py \
    && echo "c.NotebookApp.notebook_dir = '/notebooks'" >> $HOME/.jupyter/jupyter_notebook_config.py \
    && fix-permissions.sh /opt \
    && fix-permissions.sh $CONDA_DIR \
    && fix-permissions.sh /notebooks \
    && fix-permissions.sh $HOME

ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" \
    fix-permissions /home/$NB_USER

ADD start.sh /usr/local/bin/start.sh
WORKDIR /notebooks
ENTRYPOINT ["tini", "--"]
CMD ["/entrypoint", "start.sh"]

USER $NB_USER
