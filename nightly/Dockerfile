FROM node:20-alpine
RUN apk add --no-cache bash tzdata busybox-suid
COPY cronfile /etc/crontabs/root
CMD ["crond", "-f", "-l", "8"]