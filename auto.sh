#!/bin/bash
ca_crt="ca.crt"
ca_key="ca.key"
is_ecc=false
ca_subj="/CN=github.com"
server_subj="/CN=github.com"

#Country Name (2 letter code) [XX]:     
#State or Province Name (full name) []:       
#Locality Name (eg, city) [Default City]:     
#Organization Name (eg, company) [Default Company Ltd]:          
#Organizational Unit Name (eg, section) []:                     
#Common Name (eg, your name or your server's hostname) []:www.myweb.com 
#Email Address []: 
#An optional company name []:

#about do_clear()
is_clear=false
mk_rnd=false
mk_ca_dir=false


show_usage(){
    echo "usage:"
    echo "  -ca   : provide CA file"
    echo "  -key  : provide CA key"
    echo "  -ecc  : use ecc as encryption method"
    echo "  -sub j: information used to generate CSR"
    echo "  -clear: remove files created by the script, including *.csr RANDFILE CAdemo"
}
#check ca and key
get_args(){
    ARGS=`getopt -l ecc,clear,ca:,key:,subj: -- "$@"`
    eval set -- "${ARGS}"
    while true
    do
        case $1 in
            -ecc)
                is_ecc=true;
                shift
                ;;
            -clear)
                is_clear=true;
                shift
                ;;
            -ca)
                ca_crt=$2;
                shift 2
                ;;
            -key)
                ca_key=$2;
                shift2
                ;;
            -subj)
                ca_subj=$2;
                server_subj=$2;
                shift2;
                ;;
            --)
                shift2;
                break;
            ;;
        esac
    done
    if [[ $@ != "" ]]
    then
        show_usage
    fi
}

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
        openssl ecparam -genkey -name prime256v1 -out ${ca_key} #ecc
    else
        echo "generate private key.."
        openssl genrsa -out ${ca_key} 2048
    fi

    echo "generate CSR.."
    openssl req -new -key ${ca_key} -out ca.csr -subj ${ca_subj}

    echo "create self-signed certificate.."
    openssl req -x509 -days 3650 -key ${ca_key} -in ca.csr -out ${ca_crt}
    #echo "check certificate.."
    #openssl x509 -in ${ca_crt} -text -noout
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
    -cert ${ca_crt} -keyfile ${ca_key} -policy policy_anything

    #echo "check and verify certificate.."
    #openssl x509 -in server.crt -text -noout
    openssl verify -CAfile ${ca_crt} server.crt
}

do_clear(){
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
findca=`ls ${ca_crt} 2>/dev/null`
findkey=`ls ${ca_key} 2>/dev/null`
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
if ${is_clear}
then
    do_clear
fi
