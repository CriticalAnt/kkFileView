FROM keking/kkfileview-base:5.0.0
ADD kkFileView-*.tar.gz /opt/
# The tar.gz extracts to /opt/kkFileView-<version>/; link it to a stable path so
# app upgrades don't require editing this file. Keep exactly ONE tar.gz in the
# build context or the glob below fails the build.
RUN ln -s /opt/kkFileView-* /opt/kkFileView && \
    ln -s /opt/kkFileView/bin/kkFileView-*.jar /opt/kkFileView/bin/kkFileView.jar
ENV KKFILEVIEW_BIN_FOLDER=/opt/kkFileView/bin
ENTRYPOINT ["java","-Dfile.encoding=UTF-8","-Dspring.config.location=/opt/kkFileView/config/application.properties","-jar","/opt/kkFileView/bin/kkFileView.jar"]
