<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>kkFileView</title>
    <link rel="icon" href="./favicon.ico" type="image/x-icon">
    <link rel="stylesheet" href="bootstrap/css/bootstrap.min.css"/>
    <link rel="stylesheet" href="css/loading.css"/>
    <link rel="stylesheet" href="css/theme.css"/>
    <link rel="stylesheet" href="css/main-pages.css?v=v1-polish-20260411-5"/>
    <script type="text/javascript" src="js/jquery-3.6.1.min.js"></script>
    <script type="text/javascript" src="js/jquery.form.min.js"></script>
    <script type="text/javascript" src="bootstrap/js/bootstrap.min.js"></script>
    <script type="text/javascript" src="js/base64.min.js"></script>
    <script type="text/javascript" src="js/crypto-js.js"></script>
    <script type="text/javascript" src="js/aes.js"></script>
</head>

<body class="app-shell app-home">

<div class="page-shell">
    <div class="container" role="main">
        <section class="workspace-section">
            <div class="workspace-card">
                <div class="workspace-header">
                    <div>
                        <h3>文件链接预览</h3>
                    </div>
                </div>

                <div class="preview-panel">
                    <form action="${baseUrl}onlinePreview" target="_blank" id="previewByUrl">
                        <input type="hidden" name="url"/>
                        <div class="preview-options">
                            <div class="preview-switches">
                                <label><input type="checkbox" name="forceUpdatedCache" value="true"/> 更新缓存</label>
                                <label><input type="checkbox" name="kkagent" value="true"/> 跨域代理</label>
                                <label><input type="checkbox" id="encryption" name="encryption" value="aes"/> AES 加密</label>
                            </div>
                            <div class="preview-grid">
                                <input type="text" id="filePassword" name="filePassword" class="form-control" placeholder="文件密码"/>
                                <input type="text" id="page" name="page" class="form-control" placeholder="页码"/>
                                <input type="text" id="highlightall" name="highlightall" class="form-control" placeholder="高亮关键字"/>
                                <input type="text" id="watermarkTxt" name="watermarkTxt" class="form-control" placeholder="水印文本"/>
                                <#if isshowkey>
                                    <input type="text" id="kkkey" name="key" class="form-control" placeholder="KK 秘钥"/>
                                </#if>
                            </div>
                        </div>
                        <div class="preview-url">
                            <input type="text" id="_url" class="form-control" placeholder="请输入预览文件 URL，例如 https://example.com/demo.pdf"/>
                            <input type="submit" value="立即预览" class="preview-submit">
                        </div>
                    </form>
                    <div class="alert alert-danger alert-dismissable hide" role="alert" id="previewCheckAlert">
                        <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                            <span aria-hidden="true">&times;</span>
                        </button>
                        <strong>请输入正确的 URL</strong>
                    </div>
                </div>
            </div>

            <div class="workspace-card" style="margin-top: 20px;">
                <div class="workspace-header">
                    <div>
                        <h3>上传文件预览</h3>
                    </div>
                </div>
                <div class="toolbar-grid">
                    <div class="toolbar-card">
                        <#if fileUploadDisable == false>
                            <form enctype="multipart/form-data" id="fileUpload">
                                <div class="toolbar-inline">
                                    <input type="file" id="file" name="file" class="form-control"/>
                                    <input type="button" id="fileUploadBtn" class="btn toolbar-btn" value="上传文件"/>
                                </div>
                            </form>
                        <#else>
                            <div class="disabled-upload">
                                <div class="alert alert-warning">
                                    <span class="glyphicon glyphicon-info-sign"></span>
                                    文件上传功能已禁用。如需开启，请修改配置文件或联系管理员。
                                </div>
                            </div>
                        </#if>
                    </div>
                </div>
            </div>
        </section>
    </div>
</div>

<div class="loading_container" style="position: fixed;">
    <div class="spinner">
        <div class="spinner-container container1">
            <div class="circle1"></div>
            <div class="circle2"></div>
            <div class="circle3"></div>
            <div class="circle4"></div>
        </div>
        <div class="spinner-container container2">
            <div class="circle1"></div>
            <div class="circle2"></div>
            <div class="circle3"></div>
            <div class="circle4"></div>
        </div>
        <div class="spinner-container container3">
            <div class="circle1"></div>
            <div class="circle2"></div>
            <div class="circle3"></div>
            <div class="circle4"></div>
        </div>
    </div>
</div>

<#if beian?? && beian != "default">
    <div class="site-footer">
        <a target="_blank" href="https://beian.miit.gov.cn/">${beian}</a>
    </div>
</#if>

<script>
    <#if "${kkkey}" != "false" >
        <#if isshowkey>
            var _kkkey = "${kkkey}";
        </#if>
    </#if>

    function checkUrl(url) {
        <#if "${kkkey}" != "false" >
            var kkkey = document.getElementById("kkkey");
            if (!kkkey || kkkey.value == "") {
                alert("程序需要秘钥接入，请输入秘钥:<#if isshowkey><#if "${kkkey}" != "false" >${kkkey}</#if><#else>,联系系统管理员获取</#if>");
                return false;
            }
        </#if>
        var strRegex = '^((https|http|ftp|file)://)'
        var re = new RegExp(strRegex, 'i');
        return re.test(encodeURI(url));
    }

    $(function () {
        $('#previewByUrl').submit(function(e) {
            e.preventDefault();
            handlePreview();
            return false;
        });

        $("#fileUploadBtn").click(function () {
            uploadFile();
        });
    });

    function handlePreview() {
        var _url = $("#_url").val();
        if (!checkUrl(_url)) {
            $("#previewCheckAlert").addClass("show");
            window.setTimeout(function () {
                $("#previewCheckAlert").removeClass("show");
            }, 3000);
            return false;
        }

        var checkbox = document.getElementById('encryption');
        var isChecked = checkbox.checked;
        var urlaes;

        if(isChecked){
            password = prompt("<#if isshowaeskey><#if aeskey?? && aeskey != "false" && aeskey != "">接入AES秘钥是：${aeskey}<#else>请向管理员获取AES秘钥</#if><#else>请输入AES秘钥</#if>");
            if (password === null || password === undefined) {
                return false;
            }
            urlaes = aesEncrypt(_url, password);
        }else{
            urlaes = Base64.encode(_url);
        }

        var previewUrl = buildPreviewUrl(urlaes, isChecked);
        window.open(previewUrl, '_blank');
    }

    function buildPreviewUrl(encodedUrl, isEncrypted) {
        var baseUrl = '${baseUrl}onlinePreview?';
        var params = [];

        params.push('url=' + encodeURIComponent(encodedUrl));

        if ($('#previewByUrl [name=forceUpdatedCache]').is(':checked')) {
            params.push('forceUpdatedCache=true');
        }
        if ($('#previewByUrl [name=kkagent]').is(':checked')) {
            params.push('kkagent=true');
        }
        if (isEncrypted) {
            params.push('encryption=aes');
        }

        var filePassword = $('#filePassword').val();
        if (filePassword) {
            params.push('filePassword=' + encodeURIComponent(filePassword));
        }

        var page = $('#page').val();
        if (page) {
            params.push('page=' + encodeURIComponent(page));
        }

        var highlightall = $('#highlightall').val();
        if (highlightall) {
            params.push('highlightall=' + encodeURIComponent(highlightall));
        }

        var watermarkTxt = $('#watermarkTxt').val();
        if (watermarkTxt) {
            params.push('watermarkTxt=' + encodeURIComponent(watermarkTxt));
        }

        var key = $('#kkkey').val();
        if (key) {
            params.push('key=' + encodeURIComponent(key));
        }

        return baseUrl + params.join('&');
    }

    function aesEncrypt(encryptString, key) {
        var key = CryptoJS.enc.Utf8.parse(key);
        var srcs = CryptoJS.enc.Utf8.parse(encryptString);
        var encrypted = CryptoJS.AES.encrypt(srcs, key, { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 });
        return encrypted.toString();
    }

    function showLoadingDiv() {
        var height = window.document.documentElement.clientHeight - 1;
        $(".loading_container").css("height", height).show();
    }

    function uploadFile() {
        var filepath = $("#file").val();
        if(!checkFileSize(filepath)) {
            return false;
        }
        if (!filepath) {
            alert('请选择要上传的文件');
            return false;
        }
        showLoadingDiv();
        var formData = new FormData();
        var file = $('#file')[0].files[0];
        formData.append('file', file);

        $.ajax({
            url: 'fileUpload',
            type: 'POST',
            data: formData,
            processData: false,
            contentType: false,
            success: function (data) {
                if (data.code === 0) {
                    var previewUrl = '${baseUrl}onlinePreview?url=' + encodeURIComponent(Base64.encode('${baseUrl}' + data.content));
                    window.open(previewUrl, '_blank');
                    $("#file").val('');
                } else {
                    alert('上传失败: ' + data.msg);
                }
                $(".loading_container").hide();
            },
            error: function () {
                alert('上传失败，请联系管理员');
                $(".loading_container").hide();
            }
        });
    }

    function checkFileSize(filepath) {
        var daxiao = "${size}";
        daxiao = daxiao.replace("MB", "");
        var maxsize = daxiao * 1024 * 1024;
        try {
            var filesize = $("#file")[0].files[0].size;
            if (filesize > 0 && filesize > maxsize) {
                alert("上传的文件不能超过${size}喔！！！");
                return false;
            } else if (filesize === 0) {
                alert("不能上传0KB文件");
                return false;
            }
        } catch (e) {
            alert("上传失败，请重试");
            return false;
        }
        return true;
    }
</script>
</body>
</html>
