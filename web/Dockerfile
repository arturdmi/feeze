FROM tokiwa-software/fzweb:main
WORKDIR /feeze
COPY . .
WORKDIR /fzweb
RUN ln -sf /feeze/web/content
RUN ln -sf /feeze/web/templates
