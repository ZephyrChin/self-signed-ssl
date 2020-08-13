#!/bin/bash
ca_crt=ca.crt
ca_key=ca.key
ca_cn="github.com"
ca_info="/C=US/CN=${ca_cn}"
server_cn="github.com"
server_info="/CN=${server_cn}"
#Country Name (2 letter code) [XX]:     
#State or Province Name (full name) []:       
#Locality Name (eg, city) [Default City]:     
#Organization Name (eg, company) [Default Company Ltd]:          
#Organizational Unit Name (eg, section) []:                     
#Common Name (eg, your name or your server's hostname) []:www.myweb.com 
#Email Address []: 
#An optional company name []:

is_match(){
    local d=`diff -eq <(openssl x509 -pubkey -noout -in $1) <(openssl rsa -pubout -in $2)`
    if [[ $d == "" ]]
    then
        return 1
    fi
}

gen_ca(){
    echo "generate private key.."
    openssl genrsa -out ca.key 2048

    echo "generate CSR.."
    openssl req -new -key ca.key -out ca.csr -subj ${ca_info}

    echo "create self-signed certificate.."
    openssl x509 -req -sha256 -days 3650 -in ca.csr -signkey ca.key -out ca.crt

    echo "check certificate.."
    openssl x509 -in ca.crt -text -noout

    rm ca.csr
}

gen_server_crt(){
    echo "generate private key.."
    openssl genrsa -out server.key 2048

    echo "generate CSR.."
    openssl req -new -key server.key -out server.csr -subj ${server_info}

    echo "submit CSR to SSL provider.."
    openssl x509 -req -sha256 -days 3650 -in server.csr \
    -CA ca.crt -CAkey ca.key -out server.crt -CAcreateserial

    echo "check and verify certificate.."
    openssl x509 -in server.crt -text -noout
    openssl verify -CAfile ca.crt server.crt

    rm server.csr
}

####main
findca=$(ls|grep ca.crt)
findkey=$(ls|grep ca.key)
if [[ ${findca} != "" && ${findkey} != "" ]]
then
    echo "ca file found"
    is_match ca.crt ca.key
    if [[ $? == 1 ]]
    then
        echo "ca file checked"
    else
        gen_ca
    fi
else
    gen_ca
fi

gen_server_crt
