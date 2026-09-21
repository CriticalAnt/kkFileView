# kkFileView 部署文档

从源码构建到 Docker 部署的完整流程。本文档基于 `custom` 分支（跟随官方版本并包含本地定制）。

## 环境要求

| 依赖 | 版本要求 |
|------|---------|
| JDK | 21 |
| Maven | 3.6+ |
| Docker | 19.03+ |
| Docker Compose | 1.27+ |

## 目录结构

```
deploy/
├── Dockerfile                  # kkFileView 应用镜像（版本无关，升级无需修改）
├── docker-compose.yml          # 编排配置
├── kkfileview-base/
│   ├── Dockerfile              # 基础镜像（JDK 21 + LibreOffice + 中文字体）
│   ├── 99-cjk-aliases.conf     # GB2312 旧字体名映射
│   ├── fonts/                  # 自定义中文字体目录
│   └── kkfileview-base.tar    # 基础镜像导出文件（不入库，需自行构建生成）
└── DEPLOY.md                   # 本文档
```

## 第一步：编译项目

在 `custom` 分支的项目根目录执行：

```shell
git checkout custom
mvn clean package -DskipTests
```

构建产物位于 `server/target/kkFileView-<版本号>.tar.gz`（版本号随 pom，当前为 5.0.2）。

## 第二步：构建基础镜像

基础镜像包含 JDK 21、LibreOffice、中文字体等运行时依赖，与应用版本无关，通常只需构建一次；官方发版升级应用时无需重建。

tag 以 `5.0.0` 为例，仅为标记，不必跟随应用版本号。

### amd64 架构

在 x86_64 机器上直接构建：

```shell
cd deploy/kkfileview-base
docker build --tag keking/kkfileview-base:5.0.0 .
```

### arm64 架构

在 arm64 机器上执行相同的构建命令即可：

```shell
cd deploy/kkfileview-base
docker build --tag keking/kkfileview-base:5.0.0 .
```

如果只有 amd64 机器但需要构建 arm64 镜像，使用 buildx 跨平台构建：

```shell
# 前提：Docker >= 19.03，安装 buildx 插件并开启 QEMU
docker run --privileged --rm tonistiigi/binfmt --install all

docker buildx build --platform=linux/arm64 -t keking/kkfileview-base:5.0.0 --push .
```

同时构建两种架构并推送：

```shell
docker buildx build --platform=linux/amd64,linux/arm64 -t keking/kkfileview-base:5.0.0 --push .
```

### 导出镜像文件

导出为 tar 文件备用或离线分发：

```shell
docker save keking/kkfileview-base:5.0.0 -o kkfileview-base.tar
```

在部署服务器上导入：

```shell
docker load -i kkfileview-base.tar
```

## 第三步：构建应用镜像

将编译产物复制到 deploy 目录，然后构建：

```shell
cp server/target/kkFileView-*.tar.gz deploy/
cd deploy
docker build --tag kkfileview-custom:5.0.2 .
```

> ⚠️ deploy 目录内**只保留一份** `kkFileView-*.tar.gz`：旧版本产物先删除再复制新版本，否则 Dockerfile 中的通配符会匹配到多个文件导致构建失败。
>
> ⚠️ 镜像 tag 使用自有命名 `kkfileview-custom:<版本>`，不要使用官方 `keking/kkfileview:*` 同名 tag，避免与 Docker Hub 官方镜像混淆。

## 第四步：启动服务

确认 `docker-compose.yml` 中镜像 tag 与上一步构建的一致，然后启动：

```shell
docker compose up -d
```

### docker-compose.yml 说明

```yaml
services:
  kkfileview:
    image: kkfileview-custom:5.0.2          # 第三步构建的自建镜像
    hostname: "fileview"
    ports:
      - 8013:8013
    environment:
      # 服务端口
      KK_SERVER_PORT: 8013
      # 请求前缀
      KK_CONTEXT_PATH: /
      KK_BASE_URL: http://<你的服务器IP>:8013
      KK_FILE_DIR: /opt/files
      # 开启文件上传
      KK_FILE_UPLOAD_DISABLE: false
      # 信任站点白名单（* 为全部信任，生产环境建议配置具体主机）
      KK_TRUST_HOST: "*"
    volumes:
      - /opt/kkfileview/files:/opt/files             # 持久化缓存目录
    privileged: true
    restart: always
```

根据实际情况修改 `KK_BASE_URL` 和端口映射。

## 升级流程（跟随官方新版本）

仓库采用双分支模型：`master` 纯镜像跟随官方，`custom` 包含全部本地定制。官方发版后：

```shell
# 1. 本地跟进官方
git checkout master
git fetch upstream
git merge --ff-only v<新版本号>
git checkout custom
git merge master          # 冲突一般只在 main/index.ftl，保留 custom 版本
git push origin master custom

# 2. 重新构建部署
mvn clean package -DskipTests
rm deploy/kkFileView-*.tar.gz                     # 清理旧产物
cp server/target/kkFileView-<新版本号>.tar.gz deploy/
cd deploy
docker build --tag kkfileview-custom:<新版本号> .
# 修改 docker-compose.yml 中 image 的 tag 后
docker compose up -d
```

基础镜像（第二步）无需重建；`deploy/Dockerfile` 已做成版本无关，无需修改。

## 常用环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `KK_SERVER_PORT` | 8012 | 服务端口 |
| `KK_CONTEXT_PATH` | / | 请求前缀 |
| `KK_BASE_URL` | default | 预览服务地址，反向代理时必须设置 |
| `KK_FILE_DIR` | default | 预览资源存储路径 |
| `KK_TRUST_HOST` | default | 信任站点白名单，逗号分隔 |
| `KK_NOT_TRUST_HOST` | default | 不信任站点黑名单，逗号分隔 |
| `KK_CACHE_ENABLED` | true | 是否启用缓存 |
| `KK_CACHE_TYPE` | jdk | 缓存实现：jdk / redis / default |
| `KK_CACHE_CLEAN_ENABLED` | true | 是否启用缓存自动清理 |
| `KK_CACHE_CLEAN_CRON` | 0 0 3 * * ? | 缓存清理 cron 表达式 |
| `KK_OFFICE_PREVIEW_TYPE` | pdf | Office 预览类型：pdf / image |
| `KK_PDF_DOWNLOAD_DISABLE` | true | 是否禁止 PDF 下载 |
| `KK_PDF_PRINT_DISABLE` | true | 是否禁止 PDF 打印 |

完整配置项见 `server/src/main/config/application.properties`。

## 验证部署

服务启动后访问 `http://<服务器IP>:<端口>`，进入首页即表示部署成功。

## 常见问题

**Q: Office 文档预览乱码**

基础镜像已内置常用中文字体（宋体、微软雅黑、黑体、楷体、仿宋及文泉驿系列）。如需额外字体，将 `.ttf`/`.ttc` 文件放入 `kkfileview-base/fonts/` 目录后重新构建基础镜像。

**Q: 反向代理后预览失败**

必须设置 `KK_BASE_URL` 为外部可访问的完整地址，例如 `https://file.example.com`。

**Q: 基础镜像构建慢**

基础镜像需下载 JDK 21、LibreOffice 等大体积包，首次构建耗时较长。Dockerfile 已配置阿里云镜像源加速。构建一次后可通过 `kkfileview-base.tar` 离线分发。

**Q: 启动容器报 iptables 错误**

```
iptables failed: fork/exec /usr/sbin/iptables: no such file or directory
```

系统缺少 iptables，Docker 端口映射依赖它：

```shell
apt-get install -y iptables
systemctl restart docker
```
