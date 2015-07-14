#!/bin/bash
# Author: Wanlong Gao <wanlong.gao@gmail.com>
#
# This script can be used to migrate blog to a new version
# of jekyll-bootstrap
# Can modify "migrate/migrate_blacklist" to add or remove
# the files which will not be updated
#
# usage: migrate.sh <bootstrap_path> <blog_path>

[ "$1" ] || bootstrap_path="/git/jekyll-bootstrap"
[ "$2" ] || blog_path="/git/gaowanlong.github.com"

# remove the non-data files
# NOTE: ensure that this remove command will not remove your important data
cd "$blog_path"
ls -1 | grep -vxf $blog_path/migrate/migrate_blacklist | xargs rm -fr

# copy non-data files from the new version
( cd $bootstrap_path && git clean -f && ls -1 | grep -vxf $blog_path/migrate/migrate_blacklist | xargs -I{} cp -rv {} $blog_path )

# set the configurations
sed -i -e 's/\(title : \)Jekyll Bootstrap/\1A Linux Developer/' \
       -e 's/\(  name : \)Name Lastname/\1Wanlong Gao/' \
       -e 's/\(  email : \)blah@email.test/\1wanlong.gao@gmail.com/' \
       -e 's/\(  github : \)username/\1gaowanlong/' \
       -e 's/  twitter : username/  weibo : lengyuex/' \
       -e 's|\(production_url : \)http://username.github.io|\1http://blog.allenx.org|' \
       -e 's|\(provider : \)google|\1getclicky|' \
       -e 's|\(site_id : \)$|\1100861056|' \
       _config.yml

# add the unstaged files
git add $(git ls-files -o --exclude-standard | grep -v -e swp -e '~')
git commit -a -m "Switch to a refresh new version"
