#!/bin/bash

# $Id install.sh $
# $Author$
# $Date:   2008-08-21$
#
# Script for installing the testbed
#
# USAGE: After unpacking, edit setenv.sh to suit your needs, run
# then run this script.


function replace(){
sed \
-e 's|\$LOG_DIR\$|'"$LOG_DIR"'|g' \
-e 's|\$TOMCAT_DIR\$|'"$TOMCAT_DIR"'|g' \
-e 's|\$FEDORA_DIR\$|'"$FEDORA_DIR"'|g' \
-e 's|\$TOMCAT_CONFIG_DIR\$|'"$TOMCAT_CONFIG_DIR"'|g' \
-e 's|\$WEBAPPS_DIR\$|'"$WEBAPPS_DIR"'|g' \
-e 's|\$GUISERVERNAME\$|'"$GUISERVERNAME"'|g' \
-e 's|\$PORTRANGE\$|'"$PORTRANGE"'|g' \
-e 's|\$FEDORASERVERNAME\$|'"$FEDORASERVERNAME"'|g' \
-e 's|\$FEDORAPORTRANGE\$|'"$FEDORAPORTRANGE"'|g' \
-e 's|\$CASSERVERLOGINURL\$|'"$CASSERVERLOGINURL"'|g' \
<$1 > $2
}

#
# Set up basic variables
#
SCRIPT_DIR=$(dirname $0)
pushd $SCRIPT_DIR > /dev/null
SCRIPT_DIR=$(pwd)
popd > /dev/null
BASEDIR=$SCRIPT_DIR/..



#
# Import settings
#
source $SCRIPT_DIR/setenv.sh


CONFIG_TEMP_DIR=`mktemp -d`


#
# Configuring all the doms config files
#
echo "Creating config files from conf.sh"
for file in $BASEDIR/data/templates/*.template ; do
  newfile1=`basename $file`;
  newfile2=$CONFIG_TEMP_DIR/${newfile1%.template};
  replace $file $newfile2
  echo "Created config file $newfile2 from template file $file"
done


##
##  Set up the tomcat
##
echo ""
echo "TOMCAT INSTALL"
echo ""

echo "Configuring the tomcat"
mkdir -p $TOMCAT_CONFIG_DIR/

# Replace the tomcat server.xml with our server.xml, and the tomcat context.xml
mkdir -p $TOMCAT_DIR/conf
cp -v $CONFIG_TEMP_DIR/server.xml $TOMCAT_DIR/conf/server.xml
cp -v $CONFIG_TEMP_DIR/context.xml $TOMCAT_DIR/conf/context.xml

# Insert tomcat setenv.sh
mkdir -p $TOMCAT_DIR/bin/
cp -v $CONFIG_TEMP_DIR/setenv.sh $TOMCAT_CONFIG_DIR/setenv.sh
rm $TOMCAT_DIR/bin/setenv.sh
ln -s $TOMCAT_CONFIG_DIR/setenv.sh $TOMCAT_DIR/bin/setenv.sh
chmod +x $TOMCAT_DIR/bin/*.sh


# Install context.xml configuration
cp -v $CONFIG_TEMP_DIR/context.xml.default $TOMCAT_CONFIG_DIR/tomcat-context-params.xml

#if we used the odd Maintenance tomcat setup, symlink stuff together again
if [ ! $TOMCAT_CONFIG_DIR -ef $TOMCAT_DIR/conf ]; then

   #first, link to context.xml into the correct location
   mkdir -p $TOMCAT_DIR/conf/Catalina/localhost
   ln -s $TOMCAT_CONFIG_DIR/tomcat-context-params.xml $TOMCAT_DIR/conf/Catalina/localhost/context.xml.default
fi

echo ""
echo "Installing custom security certificate"
echo ""
mkdir $TOMCAT_CONFIG_DIR/certs
cp $BASEDIR/data/tomcat/cacerts $TOMCAT_CONFIG_DIR/certs

echo ""
echo "EMBEDDED JBOSS INSTALL"
echo ""
echo "Unpacking the embedded jboss"
# Unpack a tomcat server
TEMPDIR=`mktemp -d`
cp $BASEDIR/data/tomcat/$JBOSSZIP $TEMPDIR
pushd $TEMPDIR > /dev/null
unzip -q -n $JBOSSZIP
mv ${JBOSSZIP%.*}/bootstrap/* $TOMCAT_DIR/lib
mv ${JBOSSZIP%.*}/lib/* $TOMCAT_DIR/lib
rm $TOMCAT_DIR/lib/jndi.properties
popd > /dev/null
rm -rf $TEMPDIR > /dev/null

# Replace the jboss remoting-service.xml files with our own that enforce the portrange
mkdir -p $TOMCAT_DIR/conf
cp -v $CONFIG_TEMP_DIR/jboss-remoting-service.xml $TOMCAT_DIR/lib/deploy/remoting-service.xml
cp -v $CONFIG_TEMP_DIR/messaging-remoting-service.xml $TOMCAT_DIR/lib/deploy/messaging/remoting-service.xml

# Replace jboss logging configuration
cp -v $CONFIG_TEMP_DIR/log4j.xml $TOMCAT_DIR/lib/log4j.xml

echo "Tomcat setup is now done"
## Tomcat is now done

echo "Installing docs"
mkdir -p $DOCS_DIR
cp -r $BASEDIR/docs/* $DOCS_DIR
echo "Docs installed"




echo ""
echo "WEBSERVICE INSTALL"
echo ""
##
## Install the doms webservices
##
echo "Installing the doms webservices into tomcat"
mkdir -p $WEBAPPS_DIR

for file in $BASEDIR/webservices/*.war ; do
     newname=`basename $file`
     newname=`expr match "$newname" '\([^0-9]*\)'`;
     newname=${newname%-}.war;
     cp -v $file $WEBAPPS_DIR/$newname
done
chmod 644 $WEBAPPS_DIR/*.war


echo "Install complete"