bundle install

git clone https://github.com/mysociety/alavetelitheme.git lib/themes/alavetelitheme

cp config/database.yml-docker config/database.yml
cp config/general.yml-example config/general.yml

createdb -h db -U postgres -T template0 -E UTF-8 template_utf8
psql -h db -U postgres -q <<EOF
update pg_database set datistemplate=true, datallowconn=false where datname='template_utf8';
EOF

createdb -h db -U postgres -T template_utf8 alaveteli_development
createdb -h db -U postgres -T template_utf8 alaveteli_test

bin/rails db:migrate db:seed
bin/rails db:migrate RAILS_ENV=test

bundle exec script/load-sample-data
bundle exec script/update-xapian-index
