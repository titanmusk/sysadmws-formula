{% if (pillar['app'] is defined) and (pillar['app'] is not none) %}
  {%- if (pillar['app']['static_apps'] is defined) and (pillar['app']['static_apps'] is not none) %}

    {%- if (pillar['certbot_staging'] is defined) and (pillar['certbot_staging'] is not none) and (pillar['certbot_staging']) %}
      {%- set certbot_staging = "--staging" %}
    {%- else %}
      {%- set certbot_staging = " " %}
    {%- endif %}

    {%- if (pillar['certbot_force_renewal'] is defined) and (pillar['certbot_force_renewal'] is not none) and (pillar['certbot_force_renewal']) %}
      {%- set certbot_force_renewal = "--force-renewal" %}
    {%- else %}
      {%- set certbot_force_renewal = " " %}
    {%- endif %}

    {%- if (pillar['acme_staging'] is defined) and (pillar['acme_staging'] is not none) and (pillar['acme_staging']) %}
      {%- set acme_staging = "--staging" %}
    {%- else %}
      {%- set acme_staging = " " %}
    {%- endif %}

    {%- if (pillar['acme_force_renewal'] is defined) and (pillar['acme_force_renewal'] is not none) and (pillar['acme_force_renewal']) %}
      {%- set acme_force_renewal = "--force" %}
    {%- else %}
      {%- set acme_force_renewal = " " %}
    {%- endif %}

    {%- set acme_custom_params = "--reloadcmd 'nginx -t && nginx -s reload'" %}

    {%- if (pillar['app_only_one'] is defined) and (pillar['app_only_one'] is not none) %}
      {%- set app_selector = pillar['app_only_one'] %}
    {%- else %}
      {%- set app_selector = 'all' %}
    {%- endif %}
    {%- for static_app, app_params in pillar['app']['static_apps'].items() -%}
      {%- if
             (app_params['enabled'] is defined) and (app_params['enabled'] is not none) and (app_params['enabled']) and
             (app_params['user'] is defined) and (app_params['user'] is not none) and
             (app_params['group'] is defined) and (app_params['group'] is not none) and
             (app_params['app_root'] is defined) and (app_params['app_root'] is not none) and

             (app_params['nginx'] is defined) and (app_params['nginx'] is not none) and
             (app_params['nginx']['vhost_config'] is defined) and (app_params['nginx']['vhost_config'] is not none) and
             (app_params['nginx']['root'] is defined) and (app_params['nginx']['root'] is not none) and
             (app_params['nginx']['server_name'] is defined) and (app_params['nginx']['server_name'] is not none) and
             (app_params['nginx']['access_log'] is defined) and (app_params['nginx']['access_log'] is not none) and
             (app_params['nginx']['error_log'] is defined) and (app_params['nginx']['error_log'] is not none) and


             (app_params['shell'] is defined) and (app_params['shell'] is not none) and

             (
               (app_selector == 'all') or
               (app_selector == static_app)
             )
      %}




{%- if ( app_params['keep_user'] is not defined ) or ( app_params['keep_user'] is defined and app_params['keep_user'] != True ) %}
static_apps_group_{{ loop.index }}:
  group.present:
    - name: {{ app_params['group'] }}

static_apps_user_{{ loop.index }}:
  user.present:
    - name: {{ app_params['user'] }}
    - gid: {{ app_params['group'] }}
    {%- if app_params['user_home'] is defined and app_params['user_home'] is not none %}
    - home: {{ app_params['user_home'] }}
    {%- else %}
    - home: {{ app_params['app_root'] }}
    {%- endif %}
    - createhome: True
    {%- if app_params['pass'] == '!' %}
    - password: '{{ app_params['pass'] }}'
    {%- else %}
    - password: '{{ app_params['pass'] }}'
    - hash_password: True
    {%- endif %}
    {%- if app_params['enforce_password'] is defined and app_params['enforce_password'] is not none and app_params['enforce_password'] == False %}
    - enforce_password: False
    {%- endif %}
    - shell: {{ app_params['shell'] }}
    - fullname: {{ 'application ' ~ static_app }}

static_apps_user_ssh_dir_{{ loop.index }}:
  file.directory:
    - name: {{ app_params['app_root'] ~ '/.ssh' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: 700
    - makedirs: True

        {%- if (app_params['app_auth_keys'] is defined) and (app_params['app_auth_keys'] is not none) %}
static_apps_user_ssh_auth_keys_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/authorized_keys' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: 600
    - contents: {{ app_params['app_auth_keys'] | yaml_encode }}
        {%- endif %}
{%- endif %}

        {%- if
               (app_params['source'] is defined) and (app_params['source'] is not none) and
               (app_params['source']['enabled'] is defined) and (app_params['source']['enabled'] is not none) and (app_params['source']['enabled']) and
               (app_params['source']['archive'] is defined) and (app_params['source']['archive'] is not none)
        %}
static_apps_app_download_arc_{{ loop.index }}:
  archive.extracted:
    - name: {{ app_params['source']['target'] }}
    - source: {{ app_params['source']['archive'] }}
    - source_hash: {{ app_params['source']['archive_hash'] }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - overwrite: {{ app_params['source']['overwrite'] }}
          {%- if (app_params['source']['if_missing'] is defined) and (app_params['source']['if_missing'] is not none) %}
    - if_missing: {{ app_params['source']['if_missing'] }}
          {%- endif %}
        {%- endif %}

# this creates if_missing dir usually, so it should be after download_arc
static_apps_nginx_root_dir_{{ loop.index }}:
  file.directory:
    - name: {{ app_params['nginx']['root'] }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: 755
    - makedirs: True

        {%- if
               (app_params['source'] is defined) and (app_params['source'] is not none) and
               (app_params['source']['enabled'] is defined) and (app_params['source']['enabled'] is not none) and (app_params['source']['enabled']) and
               (
                 ((app_params['source']['git'] is defined) and (app_params['source']['git'] is not none)) or
                 ((app_params['source']['hg'] is defined) and (app_params['source']['hg'] is not none))
               ) and
               (app_params['source']['rev'] is defined) and (app_params['source']['rev'] is not none) and
               (app_params['source']['target'] is defined) and (app_params['source']['target'] is not none)
        %}

          {%- if
                 (app_params['source']['repo_key'] is defined) and (app_params['source']['repo_key'] is not none) and
                 (app_params['source']['repo_key_pub'] is defined) and (app_params['source']['repo_key_pub'] is not none)
          %}
static_apps_user_ssh_id_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/id_repo' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: '0600'
    - contents: {{ app_params['source']['repo_key'] | yaml_encode }}

static_apps_user_ssh_id_pub_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/id_repo.pub' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: '0600'
    - contents: {{ app_params['source']['repo_key_pub'] | yaml_encode }}

static_apps_user_ssh_config_{{ loop.index }}:
  file.managed:
    - name: {{ app_params['app_root'] ~ '/.ssh/config' }}
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - mode: '0600'
    - contents: {{ app_params['source']['ssh_config'] | yaml_encode }}
          {%- endif %}

static_apps_app_checkout_{{ loop.index }}:
          {%- if (app_params['source']['git'] is defined) and (app_params['source']['git'] is not none) %}
  git.latest:
    - name: {{ app_params['source']['git'] }}
    - rev: {{ app_params['source']['rev'] }}
    - target: {{ app_params['source']['target'] }}
    - branch: {{ app_params['source']['branch'] }}
            {%- if pillar['force_reset'] is defined %}
    - force_reset: {{ pillar['force_reset'] }}
            {%- elif app_params['source']['force_reset'] is defined %}
    - force_reset: {{ app_params['source']['force_reset'] }}
            {%- else %}
    - force_reset: True
            {%- endif %}
    - force_fetch: True
            {%- if (pillar['force_checkout'] is defined and pillar['force_checkout']) or (app_params['source']['force_checkout'] is defined and app_params['source']['force_checkout']) %}
    - force_checkout: True
            {%- endif %}
            {%- if (pillar['force_clone'] is defined and pillar['force_clone']) or (app_params['source']['force_clone'] is defined and app_params['source']['force_clone']) %}
    - force_clone: True
            {%- endif %}
    - user: {{ app_params['user'] }}
          {%- elif (app_params['source']['hg'] is defined) and (app_params['source']['hg'] is not none)  %}
  hg.latest:
    - name: {{ app_params['source']['hg'] }}
    - rev: {{ app_params['source']['rev'] }}
    - target: {{ app_params['source']['target'] }}
    - user: {{ app_params['user'] }}
          {%- endif %}
          {%- if
                 (app_params['source']['repo_key'] is defined) and (app_params['source']['repo_key'] is not none) and
                 (app_params['source']['repo_key_pub'] is defined) and (app_params['source']['repo_key_pub'] is not none)
          %}
    - identity: {{ app_params['app_root'] ~ '/.ssh/id_repo' }}
          {%- endif %}
        {%- endif %}

        {%- if
               (app_params['files'] is defined) and (app_params['files'] is not none) and
               (app_params['files']['src'] is defined) and (app_params['files']['src'] is not none) and
               (app_params['files']['dst'] is defined) and (app_params['files']['dst'] is not none)
        %}
static_apps_app_files_{{ loop.index }}:
  file.recurse:
    - name: {{ app_params['files']['dst'] }}
    - source: {{ 'salt://' ~ app_params['files']['src'] }}
    - clean: False
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - dir_mode: 755
    - file_mode: 644
        {%- endif %}

        {%- if
               (app_params['setup_script'] is defined) and (app_params['setup_script'] is not none) and
               (app_params['setup_script']['cwd'] is defined) and (app_params['setup_script']['cwd'] is not none) and
               (app_params['setup_script']['name'] is defined) and (app_params['setup_script']['name'] is not none)
        %}
static_apps_app_setup_script_run_{{ loop.index }}:
  cmd.run:
    - cwd: {{ app_params['setup_script']['cwd'] }}
    - name: {{ app_params['setup_script']['name'] }}
    - runas: {{ app_params['user'] }}
        {%- endif %}

        {%- if
               (app_params['nginx']['auth_basic'] is defined) and (app_params['nginx']['auth_basic'] is not none) and
               (app_params['nginx']['auth_basic']['user'] is defined) and (app_params['nginx']['auth_basic']['user'] is not none) and
               (app_params['nginx']['auth_basic']['pass'] is defined) and (app_params['nginx']['auth_basic']['pass'] is not none)
        %}
static_apps_app_apache_utils_{{ loop.index }}:
  pkg.installed:
    - pkgs:
      - apache2-utils

static_apps_app_htaccess_user_{{ loop.index }}:
  webutil.user_exists:
    - name: '{{ app_params['nginx']['auth_basic']['user'] }}'
    - password: '{{ app_params['nginx']['auth_basic']['pass'] }}'
    - htpasswd_file: '{{ app_params['app_root'] }}/.htpasswd'
    - force: True
    - runas: {{ app_params['user'] }}

          {%- if app_params['nginx']['auth_basic']['omit_options'] is defined and app_params['nginx']['auth_basic']['omit_options'] is not none and app_params['nginx']['auth_basic']['omit_options'] %}
            {%- set auth_basic_block = 'set $toggle "Restricted Content"; if ($request_method = OPTIONS) { set $toggle off; } auth_basic $toggle; auth_basic_user_file ' ~ app_params['app_root'] ~ '/.htpasswd;' %}
          {%- else %}
            {%- set auth_basic_block = 'auth_basic "Restricted Content"; auth_basic_user_file ' ~ app_params['app_root'] ~ '/.htpasswd;' %}
          {%- endif %}
        {%- else %}
          {%- set auth_basic_block = ' ' %}
        {%- endif %}

        {%- if (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) %}
static_apps_app_nginx_ssl_dir_{{ loop.index }}:
  file.directory:
    - name: '/etc/nginx/ssl/{{ static_app }}'
    - user: root
    - group: root
    - makedirs: True
        {%- endif %}

        {%- set server_name_301 = app_params['nginx'].get('server_name_301', static_app ~ '.example.com') %}
        {%- if
               (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) and
               (app_params['nginx']['ssl']['ssl_cert'] is defined) and (app_params['nginx']['ssl']['ssl_cert'] is not none) and
               (app_params['nginx']['ssl']['ssl_key'] is defined) and (app_params['nginx']['ssl']['ssl_key'] is not none)
        %}

           {%- if app_params['nginx']['ssl']['certs_dir'] is defined and app_params['nginx']['ssl']['certs_dir'] is not none %}
static_apps_app_nginx_ssl_certs_copy_{{ loop.index }}:
  file.recurse:
    - name: '/etc/nginx/ssl/{{ static_app }}'
    - source: {{ 'salt://' ~ app_params['nginx']['ssl']['certs_dir'] }}
    - user: root
    - group: root
    - dir_mode: 700
    - file_mode: 600
           {% endif %}

static_apps_app_nginx_vhost_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/nginx/sites-available/{{ static_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['nginx']['vhost_config'] }}'
    - template: jinja
    - defaults:
        server_name: '{{ app_params['nginx']['server_name'] }}'
        server_name_301: '{{ server_name_301 }}'
        nginx_root: {{ app_params['nginx']['root'] }}
        access_log: {{ app_params['nginx']['access_log'] }}
        error_log: {{ app_params['nginx']['error_log'] }}
        app_name: {{ static_app }}
        app_root: {{ app_params['app_root'] }}
        ssl_cert: {{ app_params['nginx']['ssl']['ssl_cert'] }}
        ssl_key: {{ app_params['nginx']['ssl']['ssl_key'] }}
        ssl_cert_301: '/etc/nginx/ssl/{{ static_app }}/301_fullchain.pem'
        ssl_key_301: '/etc/nginx/ssl/{{ static_app }}/301_privkey.pem'
        auth_basic_block: '{{ auth_basic_block }}'
        ssl_chain: {{ app_params['nginx']['ssl'].get('ssl_chain', '') }}
          {%- if app_params['nginx']['vhost_defaults'] is defined and app_params['nginx']['vhost_defaults'] is not none %}
            {%- for def_key, def_val in app_params['nginx']['vhost_defaults'].items() %}
        {{ def_key }}: {{ def_val }}
            {%- endfor %}
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ static_app ~ '/301_fullchain.pem') %}
static_apps_app_nginx_ssl_link_1_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ static_app }}/301_fullchain.pem'
    - target: '/etc/ssl/certs/ssl-cert-snakeoil.pem'
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ static_app ~ '/301_privkey.pem') %}
static_apps_app_nginx_ssl_link_2_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ static_app }}/301_privkey.pem'
    - target: '/etc/ssl/private/ssl-cert-snakeoil.key'
          {%- endif %}

          {%- if
                 (app_params['nginx']['ssl']['certbot_for_301'] is defined) and (app_params['nginx']['ssl']['certbot_for_301'] is not none) and (app_params['nginx']['ssl']['certbot_for_301']) and
                 (app_params['nginx']['ssl']['certbot_email'] is defined) and (app_params['nginx']['ssl']['certbot_email'] is not none) and
                 (pillar['certbot_run_ready'] is defined) and (pillar['certbot_run_ready'] is not none) and (pillar['certbot_run_ready'])
          %}
static_apps_app_certbot_dir_{{ loop.index }}:
  file.directory:
    - name: '{{ app_params['app_root'] }}/certbot/.well-known'
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - makedirs: True

static_apps_app_certbot_run_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: '/opt/certbot/certbot-auto -n certonly --webroot {{ certbot_staging }} {{ certbot_force_renewal }} --reinstall --allow-subset-of-names --agree-tos --cert-name {{ static_app }} --email {{ app_params['nginx']['ssl']['certbot_email'] }} -w {{ app_params['app_root'] }}/certbot -d "{{ server_name_301|replace(" ", ",") }}"'

static_apps_app_certbot_replace_symlink_1_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ static_app }}/fullchain.pem && ln -s -f /etc/letsencrypt/live/{{ static_app }}/fullchain.pem /etc/nginx/ssl/{{ static_app }}/301_fullchain.pem || true'

static_apps_app_certbot_replace_symlink_2_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ static_app }}/privkey.pem && ln -s -f /etc/letsencrypt/live/{{ static_app }}/privkey.pem /etc/nginx/ssl/{{ static_app }}/301_privkey.pem || true'

static_apps_app_certbot_cron_{{ loop.index }}:
  cron.present:
    - name: '/opt/certbot/certbot-auto renew --quiet --renew-hook "service nginx configtest && service nginx restart"'
    - identifier: 'certbot_cron'
    - user: root
    - minute: 10
    - hour: 2
    - dayweek: 1
          {%- endif %}

        {%- elif
               (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) and
               (app_params['nginx']['ssl']['certbot'] is defined) and (app_params['nginx']['ssl']['certbot'] is not none) and (app_params['nginx']['ssl']['certbot']) and
               (app_params['nginx']['ssl']['certbot_email'] is defined) and (app_params['nginx']['ssl']['certbot_email'] is not none)
        %}
static_apps_app_nginx_vhost_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/nginx/sites-available/{{ static_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['nginx']['vhost_config'] }}'
    - template: jinja
    - defaults:
        server_name: '{{ app_params['nginx']['server_name'] }}'
        server_name_301: '{{ server_name_301 }}'
        nginx_root: {{ app_params['nginx']['root'] }}
        access_log: {{ app_params['nginx']['access_log'] }}
        error_log: {{ app_params['nginx']['error_log'] }}
        app_name: {{ static_app }}
        app_root: {{ app_params['app_root'] }}
        ssl_cert: '/etc/nginx/ssl/{{ static_app }}/fullchain.pem'
        ssl_key: '/etc/nginx/ssl/{{ static_app }}/privkey.pem'
        auth_basic_block: '{{ auth_basic_block }}'
          {%- if app_params['nginx']['vhost_defaults'] is defined and app_params['nginx']['vhost_defaults'] is not none %}
            {%- for def_key, def_val in app_params['nginx']['vhost_defaults'].items() %}
        {{ def_key }}: {{ def_val }}
            {%- endfor %}
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ static_app ~ '/fullchain.pem') %}
static_apps_app_nginx_ssl_link_1_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ static_app }}/fullchain.pem'
    - target: '/etc/ssl/certs/ssl-cert-snakeoil.pem'
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ static_app ~ '/privkey.pem') %}
static_apps_app_nginx_ssl_link_2_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ static_app }}/privkey.pem'
    - target: '/etc/ssl/private/ssl-cert-snakeoil.key'
          {%- endif %}

          {%- if (pillar['certbot_run_ready'] is defined) and (pillar['certbot_run_ready'] is not none) and (pillar['certbot_run_ready']) %}
static_apps_app_certbot_dir_{{ loop.index }}:
  file.directory:
    - name: '{{ app_params['app_root'] }}/certbot/.well-known'
    - user: {{ app_params['user'] }}
    - group: {{ app_params['group'] }}
    - makedirs: True

static_apps_app_certbot_run_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: '/opt/certbot/certbot-auto -n certonly --webroot {{ certbot_staging }} {{ certbot_force_renewal }} --reinstall --allow-subset-of-names --agree-tos --cert-name {{ static_app }} --email {{ app_params['nginx']['ssl']['certbot_email'] }} -w {{ app_params['app_root'] }}/certbot -d "{{ app_params['nginx']['server_name']|replace(" ", ",") }}"'

static_apps_app_certbot_replace_symlink_1_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ static_app }}/fullchain.pem && ln -s -f /etc/letsencrypt/live/{{ static_app }}/fullchain.pem /etc/nginx/ssl/{{ static_app }}/fullchain.pem || true'

static_apps_app_certbot_replace_symlink_2_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /etc/letsencrypt/live/{{ static_app }}/privkey.pem && ln -s -f /etc/letsencrypt/live/{{ static_app }}/privkey.pem /etc/nginx/ssl/{{ static_app }}/privkey.pem || true'

static_apps_app_certbot_cron_{{ loop.index }}:
  cron.present:
    - name: '/opt/certbot/certbot-auto renew --quiet --renew-hook "service nginx configtest && service nginx restart"'
    - identifier: 'certbot_cron'
    - user: root
    - minute: 10
    - hour: 2
    - dayweek: 1
          {%- endif %}

        {%- elif
               (app_params['nginx']['ssl'] is defined) and (app_params['nginx']['ssl'] is not none) and
               (app_params['nginx']['ssl']['acme'] is defined) and (app_params['nginx']['ssl']['acme'] is not none) and (app_params['nginx']['ssl']['acme'])
        %}
static_apps_app_nginx_vhost_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/nginx/sites-available/{{ static_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['nginx']['vhost_config'] }}'
    - template: jinja
    - defaults:
        server_name: '{{ app_params['nginx']['server_name'] }}'
          {%- if (app_params['nginx']['server_name_301'] is defined) and (app_params['nginx']['server_name_301'] is not none) %}
        server_name_301: '{{ app_params['nginx']['server_name_301'] }}'
          {%- else %}
        server_name_301: '{{ static_app }}.example.com'
          {%- endif %}
        nginx_root: {{ app_params['nginx']['root'] }}
        access_log: {{ app_params['nginx']['access_log'] }}
        error_log: {{ app_params['nginx']['error_log'] }}
        app_name: {{ static_app }}
        app_root: {{ app_params['app_root'] }}
        ssl_cert: '/etc/nginx/ssl/{{ static_app }}/fullchain.pem'
        ssl_key: '/etc/nginx/ssl/{{ static_app }}/privkey.pem'
        auth_basic_block: '{{ auth_basic_block }}'
          {%- if app_params['nginx']['vhost_defaults'] is defined and app_params['nginx']['vhost_defaults'] is not none %}
            {%- for def_key, def_val in app_params['nginx']['vhost_defaults'].items() %}
        {{ def_key }}: {{ def_val }}
            {%- endfor %}
          {%- endif %}

          {# at least we have snakeoil, if cert req fails #}
          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ static_app ~ '/fullchain.pem') %}
static_apps_app_nginx_ssl_link_1_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ static_app }}/fullchain.pem'
    - target: '/etc/ssl/certs/ssl-cert-snakeoil.pem'
          {%- endif %}

          {%- if not salt['file.file_exists']('/etc/nginx/ssl/' ~ static_app ~ '/privkey.pem') %}
static_apps_app_nginx_ssl_link_2_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/ssl/{{ static_app }}/privkey.pem'
    - target: '/etc/ssl/private/ssl-cert-snakeoil.key'
          {%- endif %}

          {%- if (pillar['acme_run_ready'] is defined and pillar['acme_run_ready'] is not none and pillar['acme_run_ready']) or (app_params['nginx']['ssl']['acme_run_ready'] is defined and app_params['nginx']['ssl']['acme_run_ready'] is not none and app_params['nginx']['ssl']['acme_run_ready']) %}
static_apps_app_acme_run_{{ loop.index }}:
  cmd.run:
    - cwd: /opt/acme/home
    - shell: '/bin/bash'
            {%- if (app_params['nginx']['server_name_301'] is defined) and (app_params['nginx']['server_name_301'] is not none) %}
    - name: |
        openssl verify -CAfile /opt/acme/cert/{{ static_app }}_ca.cer /opt/acme/cert/{{ static_app }}_fullchain.cer 2>&1 | grep -q -i -e error -e cannot; [ ${PIPESTATUS[1]} -eq 0 ] && /opt/acme/home/{{ app_params['nginx']['ssl']['acme_account'] }}/acme_local.sh {{ acme_custom_params }} {{ acme_staging }} {{ acme_force_renewal }} --cert-file /opt/acme/cert/{{ static_app }}_cert.cer --key-file /opt/acme/cert/{{ static_app }}_key.key --ca-file /opt/acme/cert/{{ static_app }}_ca.cer --fullchain-file /opt/acme/cert/{{ static_app }}_fullchain.cer --issue -d {{ app_params['nginx']['server_name']|replace(" ", " -d ") }} -d {{ app_params['nginx']['server_name_301']|replace(" ", " -d ") }} || true
            {%- else %}
    - name: |
        openssl verify -CAfile /opt/acme/cert/{{ static_app }}_ca.cer /opt/acme/cert/{{ static_app }}_fullchain.cer 2>&1 | grep -q -i -e error -e cannot; [ ${PIPESTATUS[1]} -eq 0 ] && /opt/acme/home/{{ app_params['nginx']['ssl']['acme_account'] }}/acme_local.sh {{ acme_custom_params }} {{ acme_staging }} {{ acme_force_renewal }} --cert-file /opt/acme/cert/{{ static_app }}_cert.cer --key-file /opt/acme/cert/{{ static_app }}_key.key --ca-file /opt/acme/cert/{{ static_app }}_ca.cer --fullchain-file /opt/acme/cert/{{ static_app }}_fullchain.cer --issue -d {{ app_params['nginx']['server_name']|replace(" ", " -d ") }} || true
            {%- endif %}

static_apps_app_acme_replace_symlink_1_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /opt/acme/cert/{{ static_app }}_fullchain.cer && ln -s -f /opt/acme/cert/{{ static_app }}_fullchain.cer /etc/nginx/ssl/{{ static_app }}/fullchain.pem || true'

static_apps_app_acme_replace_symlink_2_{{ loop.index }}:
  cmd.run:
    - cwd: /root
    - name: 'test -f /opt/acme/cert/{{ static_app }}_key.key && ln -s -f /opt/acme/cert/{{ static_app }}_key.key /etc/nginx/ssl/{{ static_app }}/privkey.pem || true'
          {%- endif %}

        {%- else %}
static_apps_app_nginx_vhost_config_{{ loop.index }}:
  file.managed:
    - name: '/etc/nginx/sites-available/{{ static_app }}.conf'
    - user: root
    - group: root
    - source: 'salt://{{ app_params['nginx']['vhost_config'] }}'
    - template: jinja
    - defaults:
        server_name: '{{ app_params['nginx']['server_name'] }}'
        server_name_301: '{{ server_name_301 }}'
        nginx_root: {{ app_params['nginx']['root'] }}
        access_log: {{ app_params['nginx']['access_log'] }}
        error_log: {{ app_params['nginx']['error_log'] }}
        app_name: {{ static_app }}
        app_root: {{ app_params['app_root'] }}
        auth_basic_block: '{{ auth_basic_block }}'
          {%- if app_params['nginx']['vhost_defaults'] is defined and app_params['nginx']['vhost_defaults'] is not none %}
            {%- for def_key, def_val in app_params['nginx']['vhost_defaults'].items() %}
        {{ def_key }}: {{ def_val }}
            {%- endfor %}
          {%- endif %}
        {%- endif %}

        {%- if app_params['nginx']['log'] is defined and app_params['nginx']['log'] is not none and app_params['nginx']['log']['dir'] is defined and app_params['nginx']['log']['dir'] is not none and app_params['nginx']['log']['dir'] and app_params['nginx']['log']['dir'] != '/var/log/nginx'  %}
static_apps_nginx_log_dir_{{ loop.index }}:
  file.directory:
    - name: '{{ app_params['nginx']['log']['dir'] }}'
    - user: {{ app_params['nginx']['log']['dir_user']|default(app_params['user']) }}
    - group: {{ app_params['nginx']['log']['dir_group']|default(app_params['group']) }}
    - mode: {{ app_params['nginx']['log']['dir_mode']|default('755') }}
    - makedirs: True

static_apps_nginx_logrotate_file_{{ loop.index }}:
  file.managed:
    - name: '/etc/logrotate.d/nginx-{{ static_app }}'
    - user: root
    - group: root
    - mode: 644
    - contents: |
        {{ app_params['nginx']['access_log'] }}
        {{ app_params['nginx']['error_log'] }} {
          rotate {{ app_params['nginx']['log']['rotate_count']|default('31') }}
          {{ app_params['nginx']['log']['rotate_when']|default('daily') }}
          missingok
          create {{ app_params['nginx']['log']['log_mode']|default('640') }} {{ app_params['nginx']['log']['log_user']|default(app_params['user']) }} {{ app_params['nginx']['log']['log_group']|default(app_params['group']) }}
          compress
          delaycompress
          postrotate
            /usr/sbin/nginx -s reopen
          endscript
        }
        {%- endif %}

        {%- if (app_params['nginx']['link_sites-enabled'] is defined and app_params['nginx']['link_sites-enabled'] is not none and app_params['nginx']['link_sites-enabled']) %}
app_link_sites_enabled_{{ loop.index }}:
  file.symlink:
    - name: '/etc/nginx/sites-enabled/{{ static_app }}.conf'
    - target: '/etc/nginx/sites-available/{{ static_app }}.conf'
        {%- endif %}

        {%- if (pillar['nginx_reload'] is defined and pillar['nginx_reload'] is not none and pillar['nginx_reload']) or (app_params['nginx']['reload'] is defined and app_params['nginx']['reload'] is not none and app_params['nginx']['reload']) %}
static_apps_nginx_reload_{{ loop.index }}:
  cmd.run:
    - runas: 'root'
    - name: 'service nginx configtest && service nginx reload'
        {%- endif %}

      {%- endif %}
    {%- endfor %}

static_apps_info_warning:
  test.configurable_test_state:
    - name: state_warning
    - changes: False
    - result: True
    - comment: |
        WARNING: State configures nginx virtual hosts, BUT it doesn't reload or restart nginx.
        WARNING: It is done so not to break running production sites on the host.
         NOTICE:
         NOTICE: CERTBOT workflow:
         NOTICE: --------------------------------------------------------------------------------------------------------------
         NOTICE: You should state.apply this state first, then check configs, reload or restart nginx, pfp-fpm manually.
         NOTICE: After that there will be /.well-known/ location ready to serve certbot request.
         NOTICE:
         NOTICE: For the second time you can run:
         NOTICE: state.apply ... pillar='{"certbot_run_ready": True}'
         NOTICE: This will activate certbot execution and active its certs in nginx.
         NOTICE:
         NOTICE: After that you can check and reload again.
         NOTICE:
         NOTICE: Also, not to be temp banned by LE when making test runs, you can run:
         NOTICE: state.apply ... pillar='{"certbot_run_ready": True, "certbot_staging": True}'
         NOTICE: This will add --staging option to certbot. Certificate will be not trusted, but LE will allow much more tests.
         NOTICE:
         NOTICE: After staging experiments you can force renewal with:
         NOTICE: state.apply ... pillar='{"certbot_run_ready": True, "certbot_force_renewal": True}'
         NOTICE: This will add --force-renewal option to certbot.
         NOTICE: --------------------------------------------------------------------------------------------------------------
         NOTICE:
         NOTICE: ACME.SH workflow:
         NOTICE: --------------------------------------------------------------------------------------------------------------
         NOTICE: acme.sh should be configured beforehand. You need to specify pillar acme_run_ready to use it:
         NOTICE: state.apply ... pillar='{"acme_run_ready": True}'
         NOTICE: This will activate acme.sh execution.
         NOTICE:
         NOTICE: Also, not to be temp banned by LE when making test runs, you can run:
         NOTICE: state.apply ... pillar='{"acme_run_ready": True, "acme_staging": True}'
         NOTICE: This will add --staging option to acme.sh. Certificate will be not trusted, but LE will allow much more tests.
         NOTICE:
         NOTICE: After staging experiments you can force renewal with:
         NOTICE: state.apply ... pillar='{"acme_run_ready": True, "acme_force_renewal": True}'
         NOTICE: This will add --force option to acme.sh.
         NOTICE: --------------------------------------------------------------------------------------------------------------
         NOTICE:
         NOTICE: You can run only one app with pillar:
         NOTICE: state.apply ... pillar='{"app_only_one": "<app_name>"}'
         NOTICE:
         NOTICE: You can run 'service nginx configtest && service nginx reload' after each app deploy with pillar:
         NOTICE: state.apply ... pillar='{"nginx_reload": True}'
  {%- endif %}
{%- endif %}
