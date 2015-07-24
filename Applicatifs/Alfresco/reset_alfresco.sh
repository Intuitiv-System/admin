#!/bin/bash

##########################
# Suppression des fichiers pour montee de version
##########################

ALFHOME=/home/alfresco/alfresco-4.2.b

ALFDATA=/home/alfresco/alf_data

#Initial test
if [[ ! -d $ALFHOME || ! -d $ALFDATA ]]; then
        echo "Please verify your variables in the script..."
        echo "quit;"
        exit 1
fi

# Logs
if [[ -d $ALFHOME/tomcat/logs ]]; then
        rm -rf $ALFHOME/tomcat/logs/*
        echo "Logs folder deleted"
else
        echo "Logs folder not exists"
fi

# Temp files
if [[ -d $ALFHOME/tomcat/temp ]]; then
        rm -rf $ALFHOME/tomcat/temp/*
        echo "Temp folder deleted"
else
        echo "Temp folder not exists"
fi

# Work folder
if [[ -d $ALFHOME/tomcat/work ]]; then
        rm -rf $ALFHOME/tomcat/work/*
        echo "Work folder deteled"
else
        echo "Work folder not exists"
fi

# SolR
if [[ -f $ALFHOME/tomcat/conf/Catalina/localhost/solr.xml ]]; then
        mv $ALFHOME/tomcat/conf/Catalina/localhost/solr.xml $ALFHOME/tomcat/conf/Catalina/localhost/solr.xml.orig
        echo "solr.xml file renamed"
else
        echo "solr.xml file not exists"
fi

# Keystore
if [[ -d $ALFHOME/alf_data/keystore ]]; then
        if [[ -d $ALFDATA/keystore ]]; then
                rm -rf $ALFDATA/keystore
        fi
        cp -R $ALFHOME/alf_data/keystore $ALFDATA/
        echo "Keystore folder copied"
else
        echo "Keystore folder not exists"
fi

# Lucene Indexes
if [[ -d $ALFDATA/lucene-indexes ]]; then
        rm -rf $ALFDATA/lucene-indexes
        echo "Lucene-indexes folder deleted"
else
        echo "Lucene-indexes folder not exists"
fi
if [[ -d $ALFDATA/backup-lucene-indexes ]]; then
        rm -rf $LAFDATA/backup-lucene-indexes
        echo "backup-lucene-indexes folder deleted"
else
        echo "backup-lucene-indexes folder not exists"
fi

exit 0