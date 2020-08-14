#!/bin/bash
ca_crt=ca.crt
ca_key=ca.key
ca_subj="/CN=github.com"
server_subj="/CN=github.com"
is_ecc=false
#clear()
mk_rnd=false
mk_ca_dir=false
#Country Name (2 letter code) [XX]:     
#State or Province Name (full name) []:       
#Locality Name (eg, city) [Default City]:     
#Organization Name (eg, company) [Default Company Ltd]:          
#Organizational Unit Name (eg, section) []:                     
#Common Name (eg, your name or your server's hostname) []:www.myweb.com 
#Email Address []: 
#An optional company name []:

#check ca and key
is_match(){
    local d=`diff -eq <(openssl x509 -pubkey -noout -in $1) <(openssl rsa -pubout -in $2)`
    if [[ $d == "" ]]
    then
        return 1
    fi
}

check_rnd(){
    local rndfile=`ls -a ~|grep .rnd`
    if [[ ${rndfile} == "" ]]
    then
        echo "create RNDFILE.."
        mk_rnd=true
        dd if=/dev/urandom of=~/.rnd bs=256 count=1
    fi
}

#demoCA
#├── index.txt
#├── index.txt.attr
#├── newcerts
#├── private
#└── serial
check_ca_dir(){
    local ca_dir=`ls|grep demoCA`
    if [[ ${ca_dir} == "" ]]
    then
        mk_ca_dir=true
        mkdir demoCA
        mkdir demoCA/newcerts demoCA/private
        touch demoCA/index.txt demoCA/index.txt.attr demoCA/serial
        echo "01" > demoCA/serial
        echo "unique_subject = no" > demoCA/index.txt.attr
    fi
}

gen_ca(){
    if $is_ecc
    then
        echo "generate private key [ecc].."
        openssl ecparam -genkey -name prime256v1 -out ca.key #ecc
    else
        echo "generate private key.."
        openssl genrsa -out ca.key 2048
    fi

    echo "generate CSR.."
    openssl req -new -key ca.key -out ca.csr -subj ${ca_subj}

    echo "create self-signed certificate.."
    openssl req -x509 -days 3650 -key ca.key -in ca.csr -out ca.crt
    #echo "check certificate.."
    #openssl x509 -in ca.crt -text -noout
}

gen_server_crt(){
    echo "create needed dirs for command [openssl ca].."
    check_ca_dir

    if $is_ecc
    then
        echo "generate private key [ecc].."
        openssl ecparam -genkey -name prime256v1 -out server.key #ecc
    else
        echo "generate private key.."
        openssl genrsa -out server.key 2048
    fi

    echo "generate CSR.."
    openssl req -new -key server.key -out server.csr -subj ${server_subj}

    echo "submit CSR to SSL provider.."
    openssl ca -in server.csr -out server.crt \
    -cert ca.crt -keyfile ca.key -policy policy_anything

    #echo "check and verify certificate.."
    #openssl x509 -in server.crt -text -noout
    openssl verify -CAfile ca.crt server.crt
}
clear(){
    if $mk_rnd
    then
        echo "rm RNDFILE.."
        rm ~/.rnd
    fi

    echo "rm csr file.."
    rm *.csr

    if $mk_ca_dir
    then
        echo "rm dir demoCA.."
        rm -rf demoCA
    fi
}
####main
check_rnd
findca=$(ls|grep ca.crt)
findkey=$(ls|grep ca.key)
if [[ ${findca} != "" && ${findkey} != "" ]]
then
    echo "ca file found"
    is_match ${ca_crt} ${ca_key}
    if [[ $? == 1 ]]
    then
        echo "ca file valid"
    else
        gen_ca
    fi
else
    gen_ca
fi

gen_server_crt
clear
