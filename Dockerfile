FROM archlinux:base-devel as builder

RUN pacman -Syu --noconfirm \
 && pacman --needed -S git pacman-contrib --noconfirm \
 && paccache -r

COPY build-aur.sh /usr/bin/build-aur
RUN chmod 755 /usr/bin/build-aur

RUN groupadd -g 1000 user\
 && useradd -m -u 1000 -g 1000 user

RUN build-aur lgogdownloader-git
RUN build-aur pkgbuild-version-updater
RUN build-aur ssmtp



FROM archlinux:base-devel
COPY --from=builder /tmp/aur/*/*.tar.zst /tmp/aur/

RUN pacman -Syu --noconfirm \
 && pacman --needed -S pacman-contrib sed expect mailutils --noconfirm \
 && pacman --noconfirm -U /tmp/aur/*.tar.zst \
 && paccache -r \
 && rm -r /tmp/aur/

COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY gog_login     /usr/bin/gog_login
RUN chmod 755  /usr/bin/entrypoint.sh /usr/bin/gog_login

RUN groupadd -g 1000 user\
  && useradd -m -u 1000 -g 1000 user
USER 1000:1000

COPY --chown=user:user  known_hosts /home/user/.ssh/known_hosts

WORKDIR /data

CMD entrypoint.sh
