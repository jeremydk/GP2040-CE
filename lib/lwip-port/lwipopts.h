/*
 * Copyright (c) 2001-2003 Swedish Institute of Computer Science.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * This file is part of the lwIP TCP/IP stack.
 *
 * Author: Simon Goldschmidt
 *
 */
#ifndef __LWIPOPTS_H__
#define __LWIPOPTS_H__

/* Prevent having to link sys_arch.c (we don't test the API layers in unit tests) */
#define NO_SYS                          1
#define MEM_ALIGNMENT                   4
#define MEMP_OVERFLOW_CHECK             2
#define LWIP_RAW                        0
#define LWIP_NETCONN                    0
#define LWIP_SOCKET                     0
#define LWIP_DHCP                       0
#define LWIP_ICMP                       1
#define LWIP_UDP                        1
#define LWIP_TCP                        1
#define ETH_PAD_SIZE                    0
#define LWIP_IP_ACCEPT_UDP_PORT(p)      ((p) == PP_NTOHS(67))

#define TCP_MSS                         (1500 /*mtu*/ - 20 /*iphdr*/ - 20 /*tcphhr*/)
#define TCP_SND_BUF                     (2 * TCP_MSS)

#define ETHARP_SUPPORT_STATIC_ENTRIES   1

#define LWIP_HTTPD_CGI                  0
#define LWIP_HTTPD_SSI                  0
#define LWIP_HTTPD_CGI_SSI              0
#define LWIP_HTTPD_SSI_INCLUDE_TAG      0
#define LWIP_HTTPD_CUSTOM_FILES         1
#define LWIP_HTTPD_FILE_EXTENSION       1
#define LWIP_HTTPD_SUPPORT_POST         1
#define LWIP_HTTPD_SUPPORT_V09          0
#define LWIP_HTTPD_SUPPORT_11_KEEPALIVE 0 // Causes lockups with CGI requests
#define LWIP_HTTPD_ABORT_ON_CLOSE_MEM_ERROR 1

// Force tcp_write to copy response data into its own pbufs. Without this,
// lwip's default (HTTP_IS_DATA_VOLATILE = 0 when LWIP_HTTPD_DYNAMIC_FILE_READ
// is off) sends file->data by zero-copy reference — which is safe only for
// ROM-backed static files. Our custom handlers stash heap-allocated buffers
// into file->data (see webconfig.cpp set_file_data), and those buffers are
// freed by fs_close_custom before all packets are ACKed. The resulting
// use-after-free surfaces as freelist bookkeeping bytes at response offset
// 0-7 on retransmit / delayed send for certain endpoints (getKeyMappings,
// getMemoryReport, etc.). Forcing COPY makes lwip own a private copy of
// every write, severing the lifetime dependency.
//
// Literal 0x01 is TCP_WRITE_FLAG_COPY (from lwip/tcp.h). Can't #include the
// header here — lwipopts.h is pulled in by lwip's own headers, so including
// lwip/tcp.h recursively breaks build ordering. The static_assert lives
// next to the first user of the macro to confirm the value stays correct.
#define HTTP_IS_DATA_VOLATILE(hs)       0x01

#define LWIP_SINGLE_NETIF               1

#endif /* __LWIPOPTS_H__ */
