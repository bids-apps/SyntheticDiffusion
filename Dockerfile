# Use an official Python runtime as a parent image
FROM centos:latest

ENV FSLDIR /usr/local/fsl
ENV PATH $PATH:/usr/local/fsl/bin
ENV FSLOUTPUTTYPE NIFTI_GZ

# Copy the current directory contents into the container at /app
COPY .  /home


RUN python /home/fslinstaller.py -ocd do	
RUN tar -xvf fsl-6.0.1-centos7_64.tar.gz -C /usr/local
RUN rm -f fsl-6.0.1-centos7_64.tar.gz
RUN yum -y install which
RUN yum -y install bzip2
RUN yum -y install wget
RUN $FSLDIR/etc/fslconf/post_install.sh -f $FSLDIR
RUN yum -y install epel-release
RUN yum -y repolist
RUN yum -y install openblas-devel.x86_64 -y
RUN . /usr/local/fsl/etc/fslconf/fsl.sh


RUN yum -y install https://centos7.iuscommunity.org/ius-release.rpm
RUN yum -y install python36u
RUN python3.6 -m ensurepip
RUN pip3 install --upgrade pip
RUN pip3 install tensorflow
RUN yum -y install git
RUN pip3 install git+https://www.github.com/keras-team/keras-contrib.git
RUN pip3 install nibabel
RUN pip3 install pillow

RUN chmod +x /home/pipeline.sh
ENTRYPOINT ["/home/pipeline.sh"]
