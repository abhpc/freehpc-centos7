# centos7.9-abhpc <!-- omit in toc -->
ABHPC on CentOS 7.9

# 目录 <!-- omit in toc -->

- [备份](#备份)
- [系统字体](#系统字体)
- [CentOS 7.9运行Workbench](#centos-79运行workbench)
- [CentOS 7.9 安装docker](#centos-79-安装docker)
  - [Docker常用教程](#docker常用教程)
    - [1.安装Docker](#1安装docker)
    - [2. 安装NVIDIA容器支持](#2-安装nvidia容器支持)
    - [3. Docker的镜像(image)管理](#3-docker的镜像image管理)

## 备份
备份原系统：
```bash
tar cvpzf backup.tgz --exclude=/proc --exclude=/lost+found --exclude=/etc/sysconfig/network-scripts/ --exclude=/mnt --exclude=/sys --exclude=/lufs --exclude=backup.tgz /
```
恢复原系统：
```bash
tar -vxf backup.tgz -C /
```

## 系统字体
安装X11字体：
```bash
yum install xorg-x11-fonts* -y
yum install -y https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
```
修改文件```/etc/fonts/fonts.conf```，在其中加入以下行：
```shell
 <dir>/usr/share/X11/fonts</dir>
 ```
然后执行：
```bash
fc-cache -fv
```
将全部字体都扫描进入，否则Abaqus和Ansys会有字体无法识别。

## CentOS 7.9运行Workbench
CentOS 7.9运行Workbench时不能使用Mate或者Xfce桌面，会有Bug，得改用KDE才行。
```bash
yum groupinstall "KDE Plasma Workspaces" -y
```

## CentOS 7.9 安装docker
### Docker常用教程


#### 1.安装Docker
首先安装yum-utils
```bash
yum install -y yum-utils
```
然后添加docker官方源到repo中去：
```bash
yum-config-manager  --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```
如果国外比较慢的话，可以考虑用清华的镜像：
```bash
sed -i 's+https://download.docker.com+https://mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo
```
接着，安装最新版的docker：
```bash
yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```
安装好以后，配置docker镜像源，添加/etc/docker/daemon.json文件，其中内容为
```bash
{"registry-mirrors":["https://registry.docker-cn.com/"]}
```
或者执行：
```bash
echo {\"registry-mirrors\":[\"https://registry.docker-cn.com/\"]} > /etc/docker/daemon.json
```
最后，启动并测试docker。启动docker：
```bash
systemctl enable docker.service
systemctl start docker.service
```
测试docker的Hello world：
```bash
docker run hello-world
```

#### 2. 安装NVIDIA容器支持
第一步：
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
```

第二步：
```bash
yum install -y nvidia-container-toolkit
```

第三步：
```bash
cat <<EOF > /etc/docker/daemon.json
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn/",
        "https://mirror.baidubce.com"
    ]
}
EOF
```

#### 3. Docker的镜像(image)管理
Docker image的概念类似于系统光盘，


