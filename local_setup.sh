apt update -y
apt upgrade -y
apt remove -y docker docker-engine docker.io containerd runc
apt update -y
apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic test"
apt update
apt install docker-ce
docker volume ls -q -f driver=nvidia-docker | xargs -r -I{} -n1 docker ps -q -a -f volume={} | xargs -r docker rm -f
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \
  apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  tee /etc/apt/sources.list.d/nvidia-docker.list
apt update
apt-get install -y nvidia-docker2
pkill -SIGHUP dockerd
docker run --runtime=nvidia --rm nvidia/cuda:9.0-base nvidia-smi
usermod -aG docker $USER
systemctl enable docker
docker network create -d bridge imagerie_nw
docker pull minio/minio
docker pull tensorflow/serving:1.12.0-gpu

docker run -d --name=capdev -p 0.0.0.0:5000:5000 --restart unless-stopped --privileged -v /dev:/dev -v /sys:/sys \
    --network imagerie_nw -e ACCESS_KEY=imagerie -e SECRET_KEY=imagerie -v $HOME/fv_do_not_delete/fvision_creds.json:/credentials.json \
    -d -e "GOOGLE_APPLICATION_CREDENTIALS=/credentials.json" agoeckel/onprem_capdev:0.1

docker run -p 0.0.0.0:80:3000 --restart unless-stopped -v $HOME/fv_do_not_delete/fvision_creds.json:/credentials.json \
    --name captureui -e CAPTURE_SERVER=http://capdev:5000 -d --network imagerie_nw \
     agoeckel/onprem-ui:0.1

docker run -p 8500:8500 -p 8501:8501 --runtime=nvidia --name localprediction  -d -e AWS_ACCESS_KEY_ID=imagerie -e AWS_SECRET_ACCESS_KEY=imagerie -e AWS_REGION=us-east-1 -e MODEL_NAME=bottle_qc -e ENV_MODEL_BASE_PATH=/models/bottle_qc \
    --restart unless-stopped --network imagerie_nw  \
    -t localprediction:latest

tensorflow_model_server --model_config_file=/models/model.config --model_config_poll_wait_seconds=60 --model_base_path=/models

sh ./system_server.sh
