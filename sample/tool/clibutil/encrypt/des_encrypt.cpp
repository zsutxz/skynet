
extern "C" {
#include "../../../../skynet/3rd/lua/lua.h"
#include "../../../../skynet/3rd/lua/lauxlib.h"
#include "../../../../skynet/3rd/lua/lualib.h"
}

#include "rijndael.h"
#include "string.h"
#include "iostream"

//Function to convert unsigned char to string of length 2
void Char2Hex(unsigned char ch, char* szHex)
{
	unsigned char byte[2];
	byte[0] = ch/16;
	byte[1] = ch%16;
	for(int i=0; i<2; i++)
	{
		if(byte[i] >= 0 && byte[i] <= 9)
			szHex[i] = '0' + byte[i];
		else
			szHex[i] = 'A' + byte[i] - 10;
	}
	szHex[2] = 0;
}

//Function to convert string of length 2 to unsigned char
void Hex2Char(char const* szHex, unsigned char& rch)
{
	rch = 0;
	for(int i=0; i<2; i++)
	{
		if(*(szHex + i) >='0' && *(szHex + i) <= '9')
			rch = (rch << 4) + (*(szHex + i) - '0');
		else if(*(szHex + i) >='A' && *(szHex + i) <= 'F')
			rch = (rch << 4) + (*(szHex + i) - 'A' + 10);
		else
			break;
	}
}    

//Function to convert string of unsigned chars to string of chars
void CharStr2HexStr(unsigned char const* pucCharStr, char* pszHexStr, int iSize)
{
	int i;
	char szHex[3];
	pszHexStr[0] = 0;
	for(i=0; i<iSize; i++)
	{
		Char2Hex(pucCharStr[i], szHex);
		strcat(pszHexStr, szHex);
	}
}

//Function to convert string of chars to string of unsigned chars
void HexStr2CharStr(char const* pszHexStr, unsigned char* pucCharStr, int iSize)
{
	int i;
	unsigned char ch;
	for(i=0; i<iSize; i++)
	{
		Hex2Char(pszHexStr+2*i, ch);
		pucCharStr[i] = ch;
	}
}
//��block������������ֽ�
void PaddingData1(std::string& str,char* szDataIn)
{
	int length=(int)strlen(str.data());
	int k=length%BLOCK_SIZE;
	int j=length/BLOCK_SIZE;
	int padding=BLOCK_SIZE-k;
	memset(szDataIn,0x00,strlen(szDataIn));
	memcpy(szDataIn,str.data(),length);
	for(int i=0;i<padding;i++)
	{
		szDataIn[j*BLOCK_SIZE+k+i]=padding;

	}
	szDataIn[j*BLOCK_SIZE+k+padding]='\0';

}


static const std::string base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static inline bool is_base64(unsigned char c) {
	return (isalnum(c) || (c == '+') || (c == '/'));
}

std::string base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len) {
	std::string ret;
	int i = 0;
	int j = 0;
	unsigned char char_array_3[3];
	unsigned char char_array_4[4];

	while (in_len--) {
		char_array_3[i++] = *(bytes_to_encode++);
		if (i == 3) {
			char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
			char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
			char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
			char_array_4[3] = char_array_3[2] & 0x3f;

			for(i = 0; (i <4) ; i++)
				ret += base64_chars[char_array_4[i]];
			i = 0;
		}
	}

	if (i)
	{
		for(j = i; j < 3; j++)
			char_array_3[j] = '\0';

		char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
		char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
		char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
		char_array_4[3] = char_array_3[2] & 0x3f;

		for (j = 0; (j < i + 1); j++)
			ret += base64_chars[char_array_4[j]];

		while((i++ < 3))
			ret += '=';

	}

	return ret;

}

std::string base64_decode(std::string const& encoded_string) {
	size_t in_len = encoded_string.size();
	int i = 0;
	int j = 0;
	int in_ = 0;
	unsigned char char_array_4[4], char_array_3[3];
	std::string ret;

	while (in_len-- && ( encoded_string[in_] != '=') && is_base64(encoded_string[in_])) {
		char_array_4[i++] = encoded_string[in_]; in_++;
		if (i ==4) {
			for (i = 0; i <4; i++)
				char_array_4[i] = (unsigned char) base64_chars.find(char_array_4[i]);

			char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
			char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
			char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

			for (i = 0; (i < 3); i++)
				ret += char_array_3[i];
			i = 0;
		}
	}

	if (i) {
		for (j = i; j <4; j++)
			char_array_4[j] = 0;

		for (j = 0; j <4; j++)
			char_array_4[j] = (unsigned char) base64_chars.find(char_array_4[j]);

		char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
		char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
		char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

		for (j = 0; (j < i - 1); j++) ret += char_array_3[j];
	}

	return ret;
}

//des CBCģʽ����ģ��, padding��ʽΪ PKCS7
//CBC model ��ʼ����chainIv ="0102030405060708"
//In ����ܵ��ַ�������
//Out ���ľ���Base64��ó����ַ�������
//inLen (In)�����ַ�������+1
//outLen (In/Out)Out buffer����, ���ܳɹ���,���ؼ����ַ�������
//hexKey 16�����ַ���������Ĭ��Ϊ16
//chainIv CBCģʽ����
bool desCbcEncode(const char *In, char *Out, unsigned int inLen, unsigned int & outLen, const char hexKey[16], const char chainIv[16])
{
	int block_num=inLen/16;
	if(inLen%16)
		block_num++;

	//������ܿ�,padding��ʽΪPKCS7
	char* p_data=new char[block_num*16+1];
	memset(p_data,0x00,block_num*16+1);
	strncpy(p_data,In,block_num*16+1);
	int k=inLen%BLOCK_SIZE;
	int j=inLen/BLOCK_SIZE;

	int padding=BLOCK_SIZE-k;
	for(int i=0;i<padding;i++)
	{
		p_data[j*BLOCK_SIZE+k+i]=padding;
	}
	p_data[j*BLOCK_SIZE+k+padding]='\0';


	//���ܺ������
	char *szDataOut= new char[block_num*16+1];
	memset(szDataOut,0,block_num*16+1);

	//CRijndael
	CRijndael oRijndael;
	oRijndael.MakeKey(hexKey, chainIv, 16, 16);

	//�����ַ���
	oRijndael.Encrypt(p_data, szDataOut, block_num*16, CRijndael::ECB);

	std::string base64_out = base64_encode((unsigned char*)szDataOut,block_num*16+1);

	//����
	delete []szDataOut;
	delete []p_data;

	//���
	if(base64_out.length()>outLen)
		return false;

	strncpy(Out, base64_out.c_str(), outLen);
	outLen = (int)base64_out.length();

	return true;
}

//des CBCģʽ����ģ��, padding��ʽΪ PKCS7
//CBC model ��ʼ����chainIv ="0102030405060708"
//In ��Base64���ܵ����ĳ���
//Out ����
//inLen Base64���ܵ����ĳ���
//outLen Out buffer����
//hexKey 16�����ַ���������Ĭ��Ϊ16
//chainIv CBCģʽ����
bool desCbcDecode(const char *In, char *Out, unsigned int inLen, unsigned int &outLen, const char hexKey[16], const char chainIv[16])
{
	//base64 decode
	std::string base64_enc(In, inLen);
	std::string base64_dec=base64_decode(base64_enc);

	//������ܿ�,padding��ʽΪPKCS7
	unsigned int enc_len = (unsigned int)base64_dec.length();
	unsigned int block_num=enc_len/16;
	if(enc_len%16)
		block_num++;

	char *enc_data = new char[block_num*16+1];
	strncpy(enc_data, base64_dec.c_str(), block_num*16);

	int k=enc_len%BLOCK_SIZE;
	int j=enc_len/BLOCK_SIZE;
	int padding=BLOCK_SIZE-k;
	for(int i=0;i<padding;i++)
	{
		enc_data[j*BLOCK_SIZE+k+i]=padding;
	}
	enc_data[j*BLOCK_SIZE+k+padding]='\0';

	//��������
	char *dec_data = new char[block_num*16+1];
	memset(dec_data, 0, block_num*16+1);

	CRijndael oRijndael;
	oRijndael.MakeKey(hexKey, chainIv, 16, 16);
	//��������
	oRijndael.Decrypt(enc_data, dec_data, block_num*16, CRijndael::ECB);

	//���
	unsigned int out_len = (int)strlen(dec_data);
    bool ret = false;
	if(out_len<outLen)
	{
		strncpy(Out, dec_data, outLen);
        outLen = out_len;
        ret = true;
	}

	//����
	delete []dec_data;
	delete []enc_data;

	return ret;
}

int des_cbc_encode(lua_State *L)
{
    size_t in_len = 0;
	const char* plain = lua_tolstring(L,1,&in_len);
    size_t len = 0;
	const char* key = lua_tolstring(L,2,&len);
    if(len < 16)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"des_cbc_encode error ,key len err!");
        return 2;
    }
	const char* chain = lua_tolstring(L,3,&len);
    if(len < 16)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"des_cbc_encode error ,chain len err!");
        return 2;
    }

    unsigned int out_len = in_len*2+24;
    char *out = new char[out_len];
    bool b_enc = desCbcEncode(plain, out, in_len+1, out_len, key, chain);
    if(b_enc != true)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"des_cbc_encode encode error!");
        return 2;
    }

    //��������
    lua_pushinteger(L,0);
    lua_pushlstring(L,out,out_len);

    //�ͷ�����
    delete []out;

    return 2;
}

int des_cbc_decode(lua_State *L)
{
    size_t in_len = 0;
	const char* cipher = lua_tolstring(L,1,&in_len);
    size_t len = 0;
	const char* key = lua_tolstring(L,2,&len);
    if(len < 16)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"des_cbc_decode error ,key len err!");
        return 2;
    }
	const char* chain = lua_tolstring(L,3,&len);
    if(len < 16)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"des_cbc_decode error ,chain len err!");
        return 2;
    }

    char *out = new char[in_len+1];
    unsigned int out_len = in_len+1;
    bool b_dec = desCbcDecode(cipher, out, in_len+1, out_len, key, chain);
    if(b_dec != true)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"des_cbc_decode decode error!");
        return 2;
    }

    //��������
    lua_pushinteger(L,0);
    lua_pushlstring(L,out,out_len);

    //�ͷ�����
    delete []out;

    return 2;
}

const unsigned char incrytable[256] = {
	0x2f,0x97,0x65,0xd8,0x19,0xfc,0x0c,0xa1,0xc3,0x2c,0x38,0x2d,0x32,0xe3,0x42,0xbe,
	0xb2,0x12,0xec,0x61,0x25,0xde,0x50,0x18,0x9c,0x16,0x37,0x24,0xdc,0xea,0x0f,0x13,
	0xca,0x63,0xeb,0x96,0x0e,0x06,0x9a,0xda,0xd1,0xb4,0xe6,0x77,0x86,0x7c,0x3c,0x05,
	0xbb,0xd4,0x8c,0x51,0x68,0x60,0x73,0x21,0x30,0x55,0xdf,0x84,0x39,0x8f,0xcc,0x9d,
	0x3d,0xa3,0x8d,0x94,0x7d,0x92,0x56,0xb0,0x9b,0x43,0x1d,0x3a,0x11,0x74,0x75,0xce,
	0xd3,0xc7,0xf6,0x98,0xad,0xf1,0x95,0x20,0x5e,0x8e,0xd2,0x5f,0x69,0xed,0x7b,0xa2,
	0xab,0x47,0xb8,0x46,0x04,0x31,0xf9,0x29,0xd5,0x4c,0xe4,0xdd,0x6e,0x10,0xdb,0x53,
	0x48,0x79,0xaa,0x14,0xbf,0x85,0x52,0x41,0x58,0x99,0xe7,0x7a,0x76,0x70,0x6b,0x4b,
	0xa6,0x4e,0x1a,0x9f,0xc1,0xf5,0x80,0xfa,0xc8,0x02,0xbc,0xf7,0xa9,0x6c,0xb6,0xa7,
	0xc6,0xf2,0x1f,0xba,0xf8,0x67,0xe2,0xc4,0x40,0x23,0xff,0x33,0xe5,0x3e,0x72,0xe9,
	0x66,0x5a,0xa5,0x17,0x35,0xac,0x54,0x28,0xa8,0xe8,0xc2,0xf0,0xc9,0xe1,0x0d,0x87,
	0x4d,0x7f,0x59,0xd7,0x8b,0xfd,0xb1,0xa4,0xb9,0x4a,0xcf,0x44,0xf3,0x81,0x6d,0x57,
	0x83,0x15,0x2a,0xb5,0x45,0xee,0x08,0x7e,0x00,0x34,0xaf,0x6a,0xf4,0x03,0xcb,0x8a,
	0xef,0xbd,0x01,0xa0,0x27,0x3f,0x09,0x90,0x07,0x22,0xfb,0xd9,0xc0,0x5b,0x4f,0xd0,
	0x2e,0x3b,0x36,0x5c,0x1b,0x49,0x6f,0x9e,0x89,0x82,0xb3,0x26,0x1c,0x2b,0x0b,0x62,
	0x88,0x0a,0xfe,0xe0,0x93,0x1e,0xc5,0x78,0x71,0x5d,0xcd,0xb7,0xd6,0xae,0x91,0x64,
};

//访问微信服务器的数据加密密码
const unsigned char incrytable_wc[256] = {
	0xe0,0xf7,0x9c,0x1b,0xc7,0xfc,0xa5,0x03,0x49,0x02,0x28,0x33,0x37,0xee,0xb2,0x1f,
	0x5d,0x05,0x16,0x3a,0x79,0xaa,0x7b,0x4a,0xcb,0x6d,0x47,0xef,0x8f,0xbe,0xaf,0x1c,
	0x1a,0xff,0xe1,0x0d,0x9b,0xb8,0xcc,0xb4,0x63,0xd3,0x78,0x5b,0x2f,0x6c,0xf5,0x4e,
	0x58,0x2e,0x3f,0xfe,0xd9,0x31,0x5f,0x2b,0x20,0x99,0x21,0xa2,0x01,0x11,0x76,0x34,
	0x80,0xd1,0xf0,0x4f,0x27,0x07,0x93,0xf6,0x10,0xc2,0xd6,0x8e,0x3e,0x94,0x90,0xe6,
	0x59,0xf1,0x32,0xdf,0xb5,0x96,0x86,0xf2,0x5e,0xfb,0xe7,0x9e,0x54,0x66,0x88,0x81,
	0xcf,0x85,0xa9,0xfa,0x60,0xd0,0x7a,0xc3,0x3b,0xce,0x55,0x70,0xbc,0x3d,0x62,0x18,
	0x17,0x38,0x2d,0x7c,0xb9,0xf4,0xeb,0xca,0xe9,0x45,0x06,0x09,0x92,0xae,0x8d,0xc6,
	0x0c,0xc8,0x24,0x48,0xe8,0xd2,0xc1,0xac,0xa6,0xde,0x68,0x82,0x53,0x3c,0x00,0x2a,
	0x98,0xc9,0x77,0xd7,0xed,0xbb,0xa4,0x43,0x15,0x91,0xdc,0x13,0x75,0x56,0x97,0x83,
	0x2c,0x69,0x39,0x84,0x7d,0xa7,0xa1,0x51,0x04,0xc4,0x1d,0xe4,0x0b,0x9d,0xab,0x5a,
	0x6a,0x9f,0xa8,0x5c,0xb3,0x42,0xba,0xb7,0x8b,0xf8,0xf9,0xe5,0x44,0xd5,0x23,0x64,
	0xb0,0xe3,0xda,0x52,0x4c,0x74,0x1e,0x30,0xcd,0x26,0xf3,0x8a,0x29,0x72,0x22,0x19,
	0xb6,0xc5,0x6e,0x9a,0x40,0x0f,0x87,0x0a,0x25,0xc0,0x08,0xdd,0x7f,0x14,0xd4,0xa0,
	0xad,0xbd,0x35,0xdb,0xa3,0x41,0xb1,0x57,0x65,0x46,0x36,0x73,0xfd,0x4d,0x71,0x89,
	0x8c,0x12,0x6f,0x67,0x6b,0xe2,0x0e,0x95,0x7e,0x4b,0xec,0xd8,0xbf,0x50,0x61,0xea,
};

//加密数据，
//输入数据：校验码，
//输出数据：额外加校验码（最后一个字节）
int IOTEncode(unsigned char indat[1500],int len,unsigned char outdat[1500])
{
	int pos = 0;
	unsigned char tempbuff[1500] ={0};
	memcpy(tempbuff,indat,len);

	//校验位
	int ChkVal = tempbuff[pos];
	//第一个数据位不加密
	outdat[pos]= tempbuff[pos];
	for(int index=1;index<len;index++)//
	{
		ChkVal ^= tempbuff[pos+index];

		outdat[pos+index] = tempbuff[pos+index]^outdat[pos+index-1]^incrytable[(index+10)%256];
	}

	//校验码
	outdat[pos+len]= ChkVal;

	return len+1;
}

//解密数据，
//输入数据，包括校验码（最后一个字节）,
//输出数据：不包括最后的校验码
int IOTDecode(unsigned char indat[1500], int len,unsigned char outdat[1500])
{
	int pos = 0;

	unsigned char tempbuff[1500];

	memcpy(tempbuff,indat,len);

	//校验位
	int ChkVal = indat[pos];
	outdat[pos]= tempbuff[pos];
	//printf("in IOTDecode:%d,%x,%x\n",0,indat[pos+0],ChkVal);
	for(int index=1;index<len-1;index++)//
	{
		outdat[pos+index] = tempbuff[pos+index]^tempbuff[pos+index-1]^incrytable[(index+10)%256];

		ChkVal ^= outdat[pos+index];
		//printf("in IOTDecode:%d,%x,%x\n",index,indat[pos+index],ChkVal);
	}

	if(tempbuff[pos+len-1]==ChkVal)
	{
		//memcpy(outdat,indat,len-1);
		//printf("in IOTDecode len:%d,\n",len-1);

		return len-1;
	}

	return 0;
}

//访问微信服务器的数据加密
//输入数据：校验码，
//输出数据：额外加校验码（最后一个字节）
int WCEncode(unsigned char indat[1500],int len,unsigned char outdat[1500])
{
	int pos = 0;
	unsigned char tempbuff[1500] ={0};
	memcpy(tempbuff,indat,len);

	//校验位
	int ChkVal = tempbuff[pos];
	//第一个数据位不加密
	outdat[pos]= tempbuff[pos];
	for(int index=1;index<len;index++)//
	{
		ChkVal ^= tempbuff[pos+index];

		outdat[pos+index] = tempbuff[pos+index]^outdat[pos+index-1]^incrytable_wc[(index+10)%256];
	}

	//校验码
	outdat[pos+len]= ChkVal;

	return len+1;
}

//解密数据，
//输入数据，包括校验码（最后一个字节）,
//输出数据：不包括最后的校验码
int WCDecode(unsigned char indat[1500], int len,unsigned char outdat[1500])
{
	int pos = 0;

	unsigned char tempbuff[1500];

	memcpy(tempbuff,indat,len);

	//校验位
	int ChkVal = indat[pos];
	outdat[pos]= tempbuff[pos];
	//printf("in IOTDecode:%d,%x,%x\n",0,indat[pos+0],ChkVal);
	for(int index=1;index<len-1;index++)//
	{
		outdat[pos+index] = tempbuff[pos+index]^tempbuff[pos+index-1]^incrytable_wc[(index+10)%256];

		ChkVal ^= outdat[pos+index];
		//printf("in IOTDecode:%d,%x,%x\n",index,indat[pos+index],ChkVal);
	}

	if(tempbuff[pos+len-1]==ChkVal)
	{
		//memcpy(outdat,indat,len-1);
		//printf("in IOTDecode len:%d,\n",len-1);

		return len-1;
	}

	return 0;
}

int liot_encode(lua_State *L)
{
    size_t in_len = 0;
	const char* plain = lua_tolstring(L,1,&in_len);

	// printf("in liot_encode str :%s\n",(char*)plain);
	// for(size_t i = 0;i<in_len;i++)
	// {
	// 	printf(",%x",plain[i]);
	// }
	// printf("\n");

    unsigned char *out = new unsigned char[in_len+3];
	memset(out,0,in_len+3);

    int out_len = IOTEncode((unsigned char*)plain, in_len, out);

 	lua_pushinteger(L,out_len);
    lua_pushlstring(L,(char *)out,out_len);
	
	// printf("in liot_encode out str:%x,%x",out[0],out[1]);
	// for(size_t i = 0;i<in_len+1;i++)
	// {
	// 	printf(",%x",out[2+i]);
	// }
	// printf("\n");
	
	//
    delete []out;

    return 2;
}

int liot_decode(lua_State *L)
{
    size_t in_len = 0;
	const char* cipher = lua_tolstring(L,1,&in_len);
 
    if(in_len <=3)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"liot_decode decode error!");
        return 2;
    }

	// printf("in liot_decode in str:");
	// for(size_t i = 0;i<in_len;i++)
	// {
	// 	printf(",%x",(unsigned char)cipher[i]);
	// }
	// printf("\n");

    unsigned char *out = new unsigned char[in_len-1];
   	memset(out,0,in_len-1);

    unsigned int out_len = IOTDecode((unsigned char*)cipher,in_len, out);
		
	// printf("in liot_decode out str:");
	// for(size_t i = 0;i<out_len;i++)
	// {
	// 	printf(",%x",out[i]);
	// }
	// printf("\n");

 	lua_pushinteger(L,out_len);
    lua_pushlstring(L,(char*)out,out_len);

    //�ͷ�����
    delete []out;

    return 2;
}

int lwc_encode(lua_State *L)
{
    size_t in_len = 0;
	const char* plain = lua_tolstring(L,1,&in_len);


    unsigned char *out = new unsigned char[in_len+3];
	memset(out,0,in_len+3);

    int out_len = WCEncode((unsigned char*)plain, in_len, out);

 	lua_pushinteger(L,out_len);
    lua_pushlstring(L,(char *)out,out_len);
	
	//
    delete []out;

    return 2;
}

int lwc_decode(lua_State *L)
{
    size_t in_len = 0;
	const char* cipher = lua_tolstring(L,1,&in_len);
 
    if(in_len <=3)
    {
        lua_pushinteger(L,-1);
        lua_pushstring(L,"lwc_decode decode error!");
        return 2;
    }

    unsigned char *out = new unsigned char[in_len-1];
   	memset(out,0,in_len-1);

    unsigned int out_len = WCDecode((unsigned char*)cipher,in_len, out);
		

 	lua_pushinteger(L,out_len);
    lua_pushlstring(L,(char*)out,out_len);

    //�ͷ�����
    delete []out;

    return 2;
}

//��������
extern "C" int luaopen_des_encrypt(lua_State *L)
{
    static const struct luaL_Reg l[] = {
        { "des_cbc_encode", des_cbc_encode},
        { "des_cbc_decode", des_cbc_decode},
		{ "iot_encode", liot_encode},
		{ "iot_decode", liot_decode},
		{ "wc_encode", lwc_encode},
		{ "wc_decode", lwc_decode},
        { NULL, NULL}
    };
	luaL_newlib(L,l);
	return 1;
}


