#!/bin/bash
#
#
####################################
#
# Script that removes Solr system
# and replaces it by Lucene
#
####################################
#
#

# !!! Edit this value with your installation context !!!
ALFHOME=/home/transdev/alfresco-4.2.b




#Initial test
if [[ ! -d $ALFHOME ]]; then
        echo "$ALFHOME doesn't exist..."
        echo "Please edit this script and fix the variable ALFHOME at the beginning of its"
        exit 1
fi


#Comment out a line in context.xml
################################
FILE=$ALFHOME/tomcat/conf/context.xml

sed -i 's#^<Valve className="org.apache.catalina.authenticator.SSLAuthenticator" securePagesWithPragma="false" />#<!-- <Valve className="org.apache.catalina.authenticator.SSLAuthenticator" securePagesWithPragma="false" /> -->#g' $FILE



#Add lines in tomcat-users.xml
#################################
USERSFILE=$ALFHOME/tomcat/conf/tomcat-users.xml
LINE="<tomcat-users>"
LINENB=$(awk '$0 == "<tomcat-users>" {print NR}' $USERSFILE)
AFTERUSERS=$(grep -C 1 "<tomcat-users>" $USERSFILE | awk 'NR == 3 {print $2}')

#Is the file already modified ?
if [[ $AFTERUSERS != "rolename=\"admin-gui\"/>" ]]; then
        sed -i "${LINENB} a\  <role rolename=\"admin-gui\"/>\n  <role rolename=\"manager-gui\"/>\n  <user username=\"tomcat\" password=\"yourpassword\" roles=\"manager-gui,admin-gui\"/>" $USERSFILE
else
        echo "$USERSFILE was already edited to remove solr"
fi


#Delete solr folder and WAR
#################################
WEBAPPS=$ALFHOME/tomcat/webapps

if [[ -d $WEBAPPS/solr ]]; then
        rm -rf $WEBAPPS/solr
        echo "Solr folder is deleted"
else
        echo "No solr folder exists"
fi

if [[ -f $WEBAPPS/solr.war ]]; then
        mv $WEBAPPS/solr.war $ALFHOME
        echo "solr.war was moved in $ALFHOME"
else
        echo "No solr.war exists"
fi


#Edit alfresco-global.properties file
GLOBALFILE=$ALFHOME/tomcat/shared/classes/alfresco-global.properties

if [[ ! -f $GLOBALFILE.orig ]]; then
        cp $GLOBALFILE $GLOBALFILE.orig
fi

sed -i "s/^index.subsystem.name=solr/#index.subsystem.name=solr/g" $GLOBALFILE
sed -i "s/^dir.keystore/#dir.keystore/g" $GLOBALFILE
sed -i "s/^solr.port.ssl=8443/#solr.port.ssl=8443/g" $GLOBALFILE

LUCENE="index.subsystem.name=lucene"
LUCENENB=$(awk '$0 == "index.subsystem.name=lucene" {print NR}' $GLOBALFILE)

if [[ $LUCENENB != "" ]]; then
        echo "$GLOBALFILE was already edited"
else
cat >> $GLOBALFILE << "EOF"
#

### Lucene Index ###
index.subsystem.name=lucene
index.recovery.mode=FULL
dir.keystore=${dir.root}/keystore

### Home dir properties ###
spaces.user_homes.childname=cm:User_x0020_Homes

### CIFS Server Configuration ###
cifs.enabled=false

### Documents transformation & preview
# Base setting for all transformers (2 min timeout)
content.transformer.default.timeoutMs=120000
content.transformer.default.readLimitTimeMs=-1
content.transformer.default.maxSourceSizeKBytes=-1
content.transformer.default.readLimitKBytes=-1
content.transformer.default.pageLimit=-1
content.transformer.default.maxPages=-1

# text -> pdf using PdfBox (text/csv, text/xml) 10M takes about 12 seconds
content.transformer.PdfBox.TextToPdf.maxSourceSizeKBytes=10240

# pdf -> swf using Pdf2swf 2M takes about 60 seconds.
content.transformer.Pdf2swf.maxSourceSizeKBytes=5120

# txt -> pdf -> swf 5M (pdf is about the same size as the txt)
# Need this limit as transformer.PdfBox txt -> pdf is allowed up to 10M
content.transformer.complex.Text.Pdf2swf.maxSourceSizeKBytes=5120

# Transforms to PDF
# =================
content.transformer.OpenOffice.mimeTypeLimits.txt.pdf.maxSourceSizeKBytes=5120
content.transformer.OpenOffice.mimeTypeLimits.doc.pdf.maxSourceSizeKBytes=10240
content.transformer.OpenOffice.mimeTypeLimits.docx.pdf.maxSourceSizeKBytes=10240
content.transformer.OpenOffice.mimeTypeLimits.docm.pdf.maxSourceSizeKBytes=768
content.transformer.OpenOffice.mimeTypeLimits.dotx.pdf.maxSourceSizeKBytes=768
content.transformer.OpenOffice.mimeTypeLimits.dotm.pdf.maxSourceSizeKBytes=768
content.transformer.OpenOffice.mimeTypeLimits.ppt.pdf.maxSourceSizeKBytes=6144
content.transformer.OpenOffice.mimeTypeLimits.pptx.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.pptm.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.ppsx.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.ppsm.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.potx.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.potm.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.ppam.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.sldx.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.sldm.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.vsd.pdf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.mimeTypeLimits.xls.pdf.maxSourceSizeKBytes=10240
content.transformer.OpenOffice.mimeTypeLimits.xlsx.pdf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.mimeTypeLimits.xltx.pdf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.mimeTypeLimits.xlsm.pdf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.mimeTypeLimits.xltm.pdf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.mimeTypeLimits.xlam.pdf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.mimeTypeLimits.xlsb.pdf.maxSourceSizeKBytes=1536

# Transforms to SWF
# =================
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.txt.swf.maxSourceSizeKBytes=5120
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.doc.swf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.docx.swf.maxSourceSizeKBytes=1536
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.docm.swf.maxSourceSizeKBytes=256
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.dotx.swf.maxSourceSizeKBytes=256
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.dotm.swf.maxSourceSizeKBytes=256
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.ppt.swf.maxSourceSizeKBytes=6144
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.pptx.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.pptm.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.ppsx.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.ppsm.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.potx.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.potm.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.ppam.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.sldx.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.sldm.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.vsd.swf.maxSourceSizeKBytes=4096
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xls.swf.maxSourceSizeKBytes=1024
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xlsx.swf.maxSourceSizeKBytes=1024
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xltx.swf.maxSourceSizeKBytes=1024
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xlsm.swf.maxSourceSizeKBytes=1024
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xltm.swf.maxSourceSizeKBytes=1024
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xlam.swf.maxSourceSizeKBytes=1024
content.transformer.OpenOffice.Pdf2swf.mimeTypeLimits.xlsb.swf.maxSourceSizeKBytes=1024


EOF

        echo "$GLOBALFILE has been modified with lucene activation"
fi

echo ""
echo " ###########################################################################################"
echo "#                                                                                           #"
echo "# Don't forget to edit dbnames and alf_data's path in alfresco-global.properties file !!!   #"
echo "# Install those following packages :                                                        #"
echo "# aptitude install libxinerama1 libfontconfig1 libxrender1 libsm6 libice6 libxt6 fontconfig #"
echo "#                                                                                           #"
echo " ###########################################################################################"

exit 0
