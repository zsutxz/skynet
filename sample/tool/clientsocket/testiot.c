#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <resolv.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <time.h>

#define MAXBUF 4096

/************关于本文档********************************************
// *filename: ssync-client.c
*purpose: 演示网络异步通讯，这是客户端程序
*wrote by: zhoulifa(zhoulifa@163.com) 周立发(http://zhoulifa.bokee.com)
Linux爱好者 Linux知识传播者 SOHO族 开发者 最擅长C语言
*date time:2007-01-25 21:32
*Note: 任何人可以任意复制代码并运用这些文档，当然包括你的商业用途
* 但请遵循GPL
*Thanks to: Google.com
*Hope:希望越来越多的人贡献自己的力量，为科学技术发展出力
* 科技站在巨人的肩膀上进步更快！感谢有开源前辈的贡献！
*********************************************************************/

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

//加密数据，
//输入数据：校验码，
//输出数据：额外加校验码（最后一个字节）
int IOTEncode(unsigned char indat[1500],int len,unsigned char outdat[1500])
{
	int pos = 0;
    int index = 0;
	unsigned char tempbuff[1500] ={0};
	memcpy(tempbuff,indat,len);

	//校验位
	int ChkVal = tempbuff[pos];
	//第一个数据位不加密
	outdat[pos]= tempbuff[pos];
	
    for(index=1;index<len;index++)//
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
    int index = 0;
	unsigned char tempbuff[1500];

	memcpy(tempbuff,indat,len);

	//校验位
	int ChkVal = indat[pos];
	outdat[pos]= tempbuff[pos];
	//printf("in IOTDecode:%d,%x,%x,len:%d\n",0,indat[pos+0],ChkVal,len);
	for(index=1;index<len-1;index++)//
	{
		outdat[pos+index] = tempbuff[pos+index]^tempbuff[pos+index-1]^incrytable[(index+10)%256];

		ChkVal ^= outdat[pos+index];
		//printf("in IOTDecode:%d,%x,%x\n",index,indat[pos+index],ChkVal);
	}

	if(tempbuff[pos+len-1]==ChkVal)
	{
		//printf("in IOTDecode len:%d,\n",len-1);

		return len-1;
	}

	return 0;
}

//输出数据中，最开始两个字节存储有效数据的长度（长度不包括此两字节）。
//返回传输给网络的数据。
int encode_data(char indata[MAXBUF],char outdata[MAXBUF])
{
    unsigned char en_str[MAXBUF] = {0};

    //最后一个换行符不copy。
    int temp_length = strlen(indata)-1;
  
    //加密后长度会加1
    temp_length = IOTEncode((unsigned char*)indata,temp_length,en_str);
    memcpy(outdata+2,en_str,temp_length);

    outdata[0] = temp_length/256;
    outdata[1] = temp_length%256;

    //实际传输长度包括最开始两个存储长度的字节    
    return temp_length+2;
}

int main(int argc, char **argv)
{
    int sockfd, len;
    struct sockaddr_in dest;
    char buffer[MAXBUF + 1];

    fd_set rfds;
    struct timeval tv;
    int retval, maxfd = -1;

    int start=0;
    int end = 0 ;  
    // if (argc != 3) 
    // {
    //     printf("参数格式错误！正确用法如下：\n\t\t%s IP地址 端口\n\t比如:\t%s 127.0.0.1 80\n此程序用        来从某个 IP 地址的服务器某个端口接收最多 MAXBUF 个字节的消息",argv[0], argv[0]);

    //     exit(0);
    // }

    /* 创建一个 socket 用于 tcp 通信 */
    if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    {
        perror("Socket");
        exit(errno);
    }

    /* 初始化服务器端（对方）的地址和端口信息 */
    bzero(&dest, sizeof(dest));
    dest.sin_family = AF_INET;
    dest.sin_addr.s_addr = inet_addr(argv[1]);  /* IP address */

    dest.sin_port = htons(6666);
    if (inet_aton(argv[1], (struct in_addr *) &dest.sin_addr.s_addr) == 0) 
    {
        perror(argv[1]);
        exit(errno);
    }

    /* 连接服务器 */
    if (connect(sockfd, (struct sockaddr *) &dest, sizeof(dest)) != 0) 
    {
        perror("Connect error ");
        exit(errno);
    }

    printf("client ready!\n");

    while (1) 
    {
        /* 把集合清空 */
        FD_ZERO(&rfds);
        /* 把标准输入句柄0加入到集合中 */
        FD_SET(0, &rfds);
        maxfd = 0;

        /* 把当前连接句柄sockfd加入到集合中 */
        FD_SET(sockfd, &rfds);

        if (sockfd > maxfd)
        {
            maxfd = sockfd;
        }
        
        /* 设置最大等待时间 */
        tv.tv_sec = 3;
        tv.tv_usec = 0;

        /* 开始等待 */
        retval = select(maxfd + 1, &rfds, NULL, NULL, &tv);

        if (retval == -1)
        {
            printf("select error: %s, will exit!", strerror(errno));
            break;
        }
        else if (retval == 0) 
        {
            //超时，发送心跳包
            //心跳包加密其中q的ascii码为113，表示数据类型为心跳
            //ab为随机数，1234为session
            char buffer[MAXBUF + 1] = "abq1234121212345678 heart beat!";
            char tempbuff[MAXBUF + 1];

            //位置在pc模拟上要转换一下
            buffer[7] -= '0';
            int temp_len = encode_data(buffer,tempbuff);
  
            if(temp_len>0)
            {
                /* 发消息给服务器,换行符不发送 */
                len = send(sockfd, tempbuff, temp_len , 0);
            }
            
            continue;
        } 
        else 
        {
            if (FD_ISSET(sockfd, &rfds)) 
            {
                unsigned char de_str[MAXBUF + 1] = {0};
                /* 连接的socket上有消息到来则接收对方发过来的消息并显示 */
                bzero(buffer, MAXBUF + 1);

                /* 接收对方发过来的消息，最多接收 MAXBUF 个字节 */
                len = recv(sockfd, buffer, MAXBUF, 0);

                //大于9个才是有效数据
                if(len<9)
                {
                    continue;
                }
                else
                {
                    len = buffer[0]*256+buffer[1];
                }

                int de_len = IOTDecode((unsigned char*)buffer+2,len,de_str);

                if (de_len > 0)
                {
                    //与skynet通讯，前两个为大端的字符串
                    printf("receive data:%s  de_str:%s\n",buffer+2,de_str+7);
                }
                else 
                {
                    if (len < 0)
                    {
                        printf("recv error no:%d，errotstring: '%s'\n",errno, strerror(errno));
                    }
                    else
                    {
                        printf("decode error,recv data length:,%d\n",len);
                    }
                    break;
                }
            }

            if (FD_ISSET(0, &rfds))
            {
                /* 用户按键了，则读取用户输入的内容发送出去 */
                //buff的前七个字节为随机数（2），种类（1，ascii码），session（4）
                bzero(buffer, MAXBUF + 1);
                fgets(buffer, MAXBUF, stdin);
                 
                if(strlen(buffer)==0)
                {
                    strcpy(buffer,"heart\n");
                }
                if(!strncasecmp(buffer, "quit", 4)) 
                {
                    printf("自己请求终止聊天！\n");
                    break;
                }
                
                char tempbuff[MAXBUF + 1];
                //位置在pc模拟上要转换一下
                buffer[7] -= '0';
                int temp_len = encode_data(buffer,tempbuff);
                if(temp_len>0)
                {
                    /* 发消息给服务器,换行符不发送 */
                    len = send(sockfd, tempbuff, temp_len , 0);
                }

                if (len < 0)
                {
                    printf("send '%s'！error no:%d，string:'%s'\n",buffer, errno, strerror(errno));
                    break;
                } 
                else
                {
                    printf("send temp_len:%d, data2:%d,data3:%d,data7:%d ,buffer: %s\n sendstr:%s\n",
                    temp_len,(unsigned char)buffer[2],(unsigned char)buffer[3],(unsigned char)buffer[7],buffer,tempbuff);
                }
            }
        }
    }

    /* 关闭连接 */
    close(sockfd);
    return 0;
}