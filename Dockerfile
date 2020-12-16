FROM archlinux as builder

RUN pacman --needed -Sy git pacman-contrib base-devel --noconfirm \
 && paccache -r

COPY build-aur.sh /usr/bin/build-aur
RUN chmod 755 /usr/bin/build-aur

RUN groupadd -g 1000 user\
 && useradd -m -u 1000 -g 1000 user

RUN build-aur lgogdownloader-headless-git
RUN build-aur pkgbuild-version-updater
RUN build-aur ssmtp



FROM archlinux
COPY --from=builder /tmp/aur/*/*.tar.zst /tmp/aur/

RUN pacman --needed -Sy base-devel pacman-contrib sed expect mailutils --noconfirm \
 && pacman --noconfirm -U /tmp/aur/*.tar.zst \
 && paccache -r \
 && rm -r /tmp/aur/

COPY entrypoint.sh /usr/bin/entrypoint.sh
COPY gog_login     /usr/bin/gog_login
RUN chmod 755  /usr/bin/entrypoint.sh /usr/bin/gog_login

RUN groupadd -g 1000 user\
  && useradd -m -u 1000 -g 1000 user
USER 1000:1000

RUN mkdir -p "/home/user/.ssh" \
 && ssh-keyscan '95.216.144.15' >> "/home/user/.ssh/known_hosts" \
 && test "$(ssh-keygen -l -f"/home/user/.ssh/known_hosts" -F "95.216.144.15" -q -E sha256  | tr '\n' ' ')" = "95.216.144.15 RSA SHA256:5s5cIyReIfNNVGRFdDbe3hdYiI5OelHGpw2rOUud3Q8 95.216.144.15 ECDSA SHA256:uTa/0PndEgPZTf76e1DFqXKJEXKsn7m9ivhLQtzGOCI 95.216.144.15 ED25519 SHA256:RFzBCUItH9LZS0cKB5UE6ceAYhBD5C8GeOBip8Z11+4 "

WORKDIR /data

CMD entrypoint.sh
