postgres_containers=$(docker container ls -a | grep alaveteli_db | awk '{print $1}')
docker container stop $postgres_containers
docker container rm $postgres_containers
docker volume rm alaveteli_postgres

docker-compose -f docker/dev/docker-compose.yml -p alaveteli build
docker-compose -f docker/dev/docker-compose.yml -p alaveteli run app ./docker/dev/setup.sh
