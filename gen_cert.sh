#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    SSL证书生成工具 (泛域名+根域名)    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

read -p "请输入证书有效时间(年)[默认15年]: " input_years
if [ -z "$input_years" ]; then
    YEARS=15
else
    YEARS=$input_years
fi
DAYS=$(expr $YEARS \* 365)
echo -e "${YELLOW}证书有效期: ${YEARS}年 (${DAYS}天)${NC}"
echo ""

read -p "请输入证书存放目录[默认/root/cert]: " input_dir
if [ -z "$input_dir" ]; then
    CERT_DIR="/root/cert"
else
    CERT_DIR=$input_dir
fi
echo -e "${YELLOW}存放目录: ${CERT_DIR}${NC}"
echo ""

while true; do
    read -p "请输入域名(必填，如: example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}错误: 域名不能为空，请重新输入${NC}"
    else
        break
    fi
done
echo -e "${YELLOW}域名: ${DOMAIN}${NC}"
echo ""

DOMAIN_DIR="${CERT_DIR}/${DOMAIN}"
mkdir -p "${DOMAIN_DIR}"

CA_KEY="${DOMAIN_DIR}/ca.key"
CA_CERT="${DOMAIN_DIR}/ca.pem"
ROOT_KEY="${DOMAIN_DIR}/${DOMAIN}.key"
ROOT_CSR="${DOMAIN_DIR}/${DOMAIN}.csr"
ROOT_CERT="${DOMAIN_DIR}/${DOMAIN}.pem"
WILD_KEY="${DOMAIN_DIR}/wildcard.${DOMAIN}.key"
WILD_CSR="${DOMAIN_DIR}/wildcard.${DOMAIN}.csr"
WILD_CERT="${DOMAIN_DIR}/wildcard.${DOMAIN}.pem"
EXT_FILE="${DOMAIN_DIR}/cert.ext"

echo -e "${GREEN}开始生成证书...${NC}"
echo ""

echo -e "${YELLOW}[1/6] 生成CA根证书私钥...${NC}"
openssl genrsa -out "${CA_KEY}" 4096 2>/dev/null

echo -e "${YELLOW}[2/6] 生成CA根证书...${NC}"
openssl req -x509 -new -nodes -key "${CA_KEY}" -sha256 -days ${DAYS} \
    -out "${CA_CERT}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=${DOMAIN}/OU=IT/CN=${DOMAIN} Root CA" 2>/dev/null

echo -e "${YELLOW}[3/6] 生成根域名证书私钥...${NC}"
openssl genrsa -out "${ROOT_KEY}" 2048 2>/dev/null
openssl req -new -key "${ROOT_KEY}" -out "${ROOT_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=${DOMAIN}/OU=IT/CN=${DOMAIN}" 2>/dev/null

echo -e "${YELLOW}[4/6] 生成泛域名证书私钥...${NC}"
openssl genrsa -out "${WILD_KEY}" 2048 2>/dev/null
openssl req -new -key "${WILD_KEY}" -out "${WILD_CSR}" \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=${DOMAIN}/OU=IT/CN=*.${DOMAIN}" 2>/dev/null

echo -e "${YELLOW}[5/6] 签发根域名证书...${NC}"
cat > "${EXT_FILE}" << EXTEOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
EXTEOF

openssl x509 -req -in "${ROOT_CSR}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -CAcreateserial -out "${ROOT_CERT}" -days ${DAYS} -sha256 \
    -extfile "${EXT_FILE}" 2>/dev/null

echo -e "${YELLOW}[6/6] 签发泛域名证书...${NC}"
cat > "${EXT_FILE}" << EXTEOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${DOMAIN}
DNS.2 = ${DOMAIN}
EXTEOF

openssl x509 -req -in "${WILD_CSR}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -CAcreateserial -out "${WILD_CERT}" -days ${DAYS} -sha256 \
    -extfile "${EXT_FILE}" 2>/dev/null

rm -f "${ROOT_CSR}" "${WILD_CSR}" "${EXT_FILE}" "${DOMAIN_DIR}/ca.srl"
chmod 600 "${CA_KEY}" "${ROOT_KEY}" "${WILD_KEY}"
chmod 644 "${CA_CERT}" "${ROOT_CERT}" "${WILD_CERT}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}          证书生成完成！                ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "证书目录: ${DOMAIN_DIR}"
echo ""
echo "文件列表:"
echo "  CA证书:       ca.pem"
echo "  CA私钥:       ca.key"
echo "  根域名证书:   ${DOMAIN}.pem"
echo "  根域名私钥:   ${DOMAIN}.key"
echo "  泛域名证书:   wildcard.${DOMAIN}.pem"
echo "  泛域名私钥:   wildcard.${DOMAIN}.key"
echo ""
echo "Nginx配置示例:"
echo "  ssl_certificate     ${WILD_CERT};"
echo "  ssl_certificate_key ${WILD_KEY};"
