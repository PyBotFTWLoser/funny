FROM node:16-alpine as builder

# build wombat
RUN apk add git
COPY . /opt/dafunny

WORKDIR /opt/dafunny
# for whatever reason, heroku doesn't copy the .git folder and the .gitmodules file, so we're
# approaching this assuming they will never exist
RUN rm -rf .git && git init
WORKDIR /opt/dafunny/public
RUN rm -rf wombat && git submodule add https://github.com/webrecorder/wombat
WORKDIR /opt/dafunny/public/wombat
# wombat's latest version (as of January 4th, 2022; commit 72db794) breaks websocket functionality.
# Locking the version here temporarily until I can find a solution
RUN git checkout 78813ad

RUN npm install --legacy-peer-deps && npm run build-prod

# delete everything but the dist folder to save us an additional 50MB+
RUN mv dist .. && rm -rf * .git && mv ../dist/ .

# modify nginx.conf
WORKDIR /opt/dafunny

RUN ./docker-sed.sh

FROM nginx:stable-alpine

# default environment variables in case a normal user doesn't specify it
ENV PORT=80
# set SAFE_BROWSING to any value to enable it
#ENV SAFE_BROWSING=1

COPY --from=builder /opt/dafunny /opt/dafunny
RUN cp /opt/dafunny/nginx.conf /etc/nginx/nginx.conf

# make sure nginx.conf works (mainly used for development)
RUN nginx -t

CMD /opt/dafunny/docker-entrypoint.sh
