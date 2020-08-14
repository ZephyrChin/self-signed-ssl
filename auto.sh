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

#flags of do_clear()
is_clear=false
mk_rnd=false
mk_ca_dir=false

show_usage(){
    echo "usage:"
    echo "  -h    : show usage"
    echo "  -ca   : provide CA file"
    echo "  -key  : provide CA key"
    echo "  -ecc  : use ecc as encryption method"
    echo "  -subj: information used to generate CSR"
    echo "  -clear: remove files created by the script, including *.csr RANDFILE CAdemo"
}

get_args(){
    ARGS=`getopt -o h -l ecc,help,clear,ca:,key:,subj: -- "$@"`
    eval set -- "${ARGS}"
    while true
    do
        case $1 in
            -h|--help)
                show_usage;
                exit 0
                ;;
            --ecc)
                is_ecc=true;
                shift
                ;;
            --clear)
                is_clear=true;
                shift
                ;;
            --ca)
                ca_crt=$2;
                shift 2
                ;;
            --key)
                ca_key=$2;
                shift 2
                ;;
            --subj)
                ca_subj=$2;
                server_subj=$2;
                shift 2
                ;;
            --)
                shift
                break;
            ;;
        esac
    done
    if [[ $@ != "" ]]
    then
        show_usage
        exit 1
    fi
}

#check CA file
is_match(){
    local d=`diff -eq <(openssl x509 -pubkey -noout -in $1) <(openssl rsa -pubout -in $2)`
    if [[ $d == "" ]]
    then
        return 1
    fi
}

#[openssl req] requires ~/.rnd by default config
check_rnd(){
    local rndfile=`ls -a ~|grep .rnd`
    if [[ ${rndfile} == "" ]]
    then
        echo "create RNDFILE.."
        mk_rnd=true
        dd if=/dev/urandom of=~/.rnd bs=256 count=1
    fi
}

#to use command [openssl ca], these files are needed
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

#generate CA file if not provided
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

#generate another cert then auth with CA file
gen_server_crt(){
    echo "create dir for command [openssl ca].."
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
    openssl ca -days 3650 -in server.csr -out server.crt \
    -cert ${ca_crt} -keyfile ${ca_key} -policy policy_anything

    #echo "check and verify certificate.."
    #openssl x509 -in server.crt -text -noout
    openssl verify -CAfile ${ca_crt} server.crt
}

#remain RNDFILE and CAdemo if they exist before
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
get_args $@
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
