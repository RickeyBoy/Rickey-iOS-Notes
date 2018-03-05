# iOS HTTP & HTTPS 详解

## 1. HTTP 协议详解
#### 1.1 简介
- Hyper Text Transfer Protocol（超文本传输协议）
- 基于 TCP/IP 的应用层协议
- HTTP使用统一资源标识符（Uniform Resource Identifiers, URI）来传输数据和建立连接
- 默认端口为80

#### 1.2 通信流程
<img src="http://ac-HSNl7zbI.clouddn.com/nTUepWgzc8sNoiJwIAf5h216HAACExoeAu1WogRL.jpg" width="300">

#### 1.3 HTTP 特点
- 无连接：限制每次连接只能处理一个请求，服务器处理完客户的请求，并收到客户的应答后，即断开连接。采用这种方式可以节省传输时间。（在HTTP 1.1即以后不再是这样）
- 媒体独立：这意味着，只要客户端和服务器知道如何处理的数据内容，任何类型的数据都可以通过HTTP发送。
- 无状态：无状态是指协议对于事务处理没有记忆能力。
    - 如果后续处理需要前面的信息，则必须重传，这样可能导致每次连接传送的数据量增大
    - 在服务器不需要先前信息时它的应答就较快

#### 1.4 客户端请求报文 · 消息结构

**四部分**：请求行（request line）、请求头部（header）、空行、请求数据
<img src="http://ac-HSNl7zbI.clouddn.com/fkSACKUoXm9h2QikTkLToJ2cUvdX22fHEQzX2HGS.jpg" width="500">


**实例**

```HTTP
GET /hello.txt HTTP/1.1
User-Agent: curl/7.16.3 libcurl/7.16.3 OpenSSL/0.9.7l zlib/1.2.3
Host: www.example.com
Accept: */*
Accept-Language: en, mi
```

**实例解读**

- request line：核心信息
   - `GET`：请求类型
   - `/hello.txt`：请求的资源
   - `HTTP/1.1`：协议版本
- header：一些附加信息，描述客户端情况
   - `User-Agent`：用户代理，简称UA。自定义，并且在每个请求中自动发送。服务器端和客户端都能访问它，是浏览器类型检测逻辑的重要基础。
   - `HOST`：指出请求的目的地
   - `Accept` : 可接受的数据格式。`*／*` 表示可接受任何数据格式
- 空行：必须，即使没有请求数据
- 请求数据：可以为任意

#### 1.5 服务器响应报文 · 消息结构
由同样的四部分组成

**实例**

```HTTP
HTTP/1.0 200 OK 
Content-Type: text/plain
Content-Length: 137582
Expires: Thu, 05 Dec 1997 16:00:00 GMT
Last-Modified: Wed, 5 August 1996 15:55:28 GMT
Server: Apache 0.84

<html>
  <body>Hello World</body>
</html>
```

**实例解读**

- request line：核心信息
   - `HTTP/1.0`：协议版本
   - `200`：状态码（常见状态码见下表）
   - `OK`：状态消息
- header：一些附加信息，描述客户端情况
   - `Content-Type`：告知响应正文的数据格式（头信息必须是ASCII码）。
       - 常见数据类型：（见下表）
       - 数据类型总称为`MIME type`，每个值包括一级类型和二级类型，之间用斜杠分隔
       - 可自定义
    - `Content-Encoding`：数据压缩方法（正文可以为被压缩之后的内容）。客户端可以用`Accept-Encoding`字段表示可以接受的压缩方式。
- 空行：必须，即使没有请求数据
- 请求数据：正文，可以为任意

**常见状态码**

* 200 - 请求成功 
* 301 - 资源（网页等）被永久转移到其它URL 
* 404 - 请求的资源（网页等）不存在 
* 500 - 内部服务器错误 


**Content-Type 常见类型**

* text/plain
* text/html
* text/css
* image/jpeg
* image/png
* image/svg+xml
* audio/mp4
* video/mp4
* application/javascript
* application/pdf
* application/zip
* application/atom+xml

#### 1.6 HTTP 请求方法

<div><span class="Apple-tab-span" style="white-space: pre;"></span>
</div>

|  | 方法 | 描述 |
| --- | --- | --- |
| | | **HTTP 1.0 定义的方法** |
| 1 | GET | 请求指定的页面信息，并返回实体主体。 |
| 2 | HEAD | 类似于get请求，只不过返回的响应中没有具体的内容，用于获取报头 |
| 3 | POST | 向指定资源提交数据进行处理请求（修改）。数据被包含在请求体中 |
| | | **HTTP 1.1 新增的方法** |
| 4 | PUT | 从客户端向服务器传送的数据取代指定的文档的内容。 |
| 5 | DELETE | 请求服务器删除指定的页面。 |
| 6 | CONNECT | 预留给能够将连接改为管道方式的代理服务器。 |
| 7 | OPTIONS | 允许客户端查看服务器的性能。 |
| 8 | TRACE | 回显服务器收到的请求，主要用于测试或诊断。 |

**方法的性质**
征求意见稿（Request For Comments，缩写为`RFC`），是由互联网工程任务组（IETF）发布的一系列备忘录。文件收集了有关互联网相关信息，以及UNIX和互联网社区的软件文件，以编号排定。目前 RFC 文件是由互联网协会（ISOC）赞助发行。

RFC7231 里定义了HTTP方法的几个性质：
1. Safe - 安全：一个方法的语义在本质上是「只读」的，那么这个方法就是安全的。GET、HEAD、OPTIONS、TRACE
2. Idempotent - 幂等：同一个请求方法执行多次和仅执行一次的效果完全相同。安全方法 + PUT、DELETE
3. Cacheable - 可缓存性：一个方法是否可以被缓存。GET、HEAD、某些情况下的POST

#### 1.7 HTTP 1.1 版本新增

**CONNECT 持久连接 & Pipeline 管道**
在HTTP 1.1中引入了`持久连接（persistent connection）`，即TCP默认不关闭（在之前的版本中，一个请求被处理完会断开连接），可以被多个请求复用。

- `Connection: keep-alive` 默认状态
- `Connection: close` 客户端最后一个请求时会要求服务器关闭TCP连接
- HTTP 1.1 在persistent connection基础上还引入了`管道（pipeline）`机制。即在一个TCP连接上，客户端可以一次发送多个请求（因为有了persistent connection之后不用每个请求之后都断开连接）。
- 但是在同一个TCP上，服务器仍然按序响应，所以可能出现拥塞。比如`队头拥塞 Head-of-line blocking`。

#### 1.8 HTTP 2 版本新增

- 二进制协议：不止头部信息是ASCII码，正文信息也可以为ASCII，统称为帧（frame）
- 多工（Multiplexing）：服务器无需按序响应，解决`队头拥塞`
- 头部信息压缩（header compression）：压缩由于HTTP无状态而导致必须重复传送的信息
- 服务器推送（server push）：服务器可以未经允许向客户端发送消息

## 2. HTTPS 协议详解
#### 2.1 简介
- HTTP over SSL/TLS
- 需要到CA申请证书
- 使用443端口
- SSL(Secure Socket Layer，安全套接字层) or TLS (Transport Layer Security，传输层安全协议)

#### 2.2 HTTPS 目的 & 特点
- 内容加密：建立一个信息安全通道，来保证数据传输的安全；
- 身份认证：确认网站的真实性
- 数据完整性：防止内容被第三方冒充或者篡改

上述三点是整个 HTTPS 的核心，整个SSL／TLS技术都是为了实现这三点。所以牢记这三点，理解下面SSL／TLS原理，以及HTTPS的整个通信过程，就会更有条理。

#### 2.3 SSL/TLS 原理
<img src="http://ac-HSNl7zbI.clouddn.com/iuVAp4jI0bkjNLgxJ7owVX4xvuiJioot2yI2WtjG.jpg" width="400">

- 对称加密：
    - 加解密使用相同密钥。
    - 客户端和服务器使用相同密钥（会话密钥session key），将传输的信息加密之后传输，接收方收到之后进行解密，保证了传输过程中**消息的保密性**。
- 非对称加密：
    - 需要两个密钥，公钥（public key，公开的）& 私钥（secret key，保密的）
    - 公钥加密的内容只能用私钥解密，私钥加密的也只能用公钥解密。
- HASH算法（摘要算法）：将长段内容映射成唯一特定HASH值，但不可根据HASH值逆向求的原内容。
- 数字签名：
    - 发送方进行数字签名：消息（用私钥加密）+ 对应HASH值。
    - 接收方验证数字签名：消息（用公钥解密），计算对应HASH值并与接收到的HASH值对比，判断消息是否被篡改过，**保证消息完整性**。
- 数字证书：
    - 包含身份认证信息的数字签名
    - 由CA机构（Certificate Authority，证书授权中心，可看作绝对可信）发放
    - 在访问一个服务器时，服务器发送数字证书，客户端验证证书真实性，确保服务器可信，从而**实现身份认证**。

#### 2.4 通信过程
<img src="http://ac-HSNl7zbI.clouddn.com/7JyzBSytrLG58pYJfEf8OXQ3OshXhX8nG4GukYFb.jpg" width="400">

- A：客户端请求
    - 支持的协议版本（如 TLS 1.0）
    - 支持的加密方式（如 RSA）
    - 一个随机数（由客户端生成）
    - 支持的压缩方法
- B：服务器响应
    - 确认协议版本
    - 确认加密方式
    - 一个随机数（由服务器生成）
    - 服务器证书
- C：客户端回应
    - 验证服务器证书，**实现身份认证**：
        - 证书未通过验证：弹出警告
        - 证书通过验证：取出服务器公钥
    - （用服务器公钥加密）一个随机数（客户端生成，pre-master-key）
    - 编码改变通知：之后通信均要加密
    - 客户端握手结束通知：表示客户端的握手阶段已经结束。这一项同时也是前面发送的所有内容的hash值，用来供服务器校验，**确保数据完整性**。
- D：服务器最终响应
    - 编码改变通知：确认之后加密通信
    - 服务器握手结束通知：表示服务器的握手阶段已经结束。这一项同时也是前面发送的所有内容的hash值，用来供客户端校验，**确保数据完整性**。
- 虚线：握手阶段结束，开始传输阶段
    - 用三个随机数，生成会话密钥（session key）
    - 将会话密钥（session key）用于对称加密，**实现内容加密**


## 参考资料
- [HTTP 协议入门 - 阮一峰的网络日志](http://www.ruanyifeng.com/blog/2016/08/http.html)
- [关于HTTP协议，一篇就够了 - ranyonsue - 博客园](http://www.cnblogs.com/ranyonsue/p/5984001.html)
- [GET和POST的区别 - 杨光的回答 - 知乎](https://www.zhihu.com/question/28586791/answer/145424285)
- [详解https是如何确保安全的 - WangXin](http://www.wxtlife.com/2016/03/27/%E8%AF%A6%E8%A7%A3https%E6%98%AF%E5%A6%82%E4%BD%95%E7%A1%AE%E4%BF%9D%E5%AE%89%E5%85%A8%E7%9A%84%EF%BC%9F/)

