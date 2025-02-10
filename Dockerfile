FROM nickblah/lua:5.1-luarocks-alpine

WORKDIR /opt

RUN apk add --no-cache --update g++

# For openssl header files
RUN apk add curl-dev

# https://github.com/lubyk/xml/issues/16#issuecomment-913199333
RUN luarocks install xml STDCPP_LIBDIR=/usr/lib

RUN luarocks install lua-requests

COPY . /opt

