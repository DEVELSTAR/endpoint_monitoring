link https://rubyinstaller.org/downloads/

downloaded -- Ruby+Devkit 4.0.3-1 (x64) 


downloaded PostMan from link https://www.postman.com/downloads/



Useful Commands:
View Logs: docker compose logs -f app
Stop Project: docker compose down
Restart Project: docker compose up -d
Rails Console: docker compose exec app bundle exec rails console





# Databases mysql commands

mysql -u root -p
password: Root@123
USE prontooss;
SHOW TABLES;

docker exec -it endpoint_monitoring_mysql_legacy bash
docker compose exec mysql-legacy mysql -u root -pRoot@123 -e "USE prontooss; SHOW TABLES;"
docker compose exec mysql-primary mysql -u root -pRoot@123 -e "USE endpoint_monitoring; SHOW TABLES;"