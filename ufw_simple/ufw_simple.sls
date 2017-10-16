{% if (pillar['ufw_simple'] is defined) and (pillar['ufw_simple'] is not none) %}
  {%- if (pillar['ufw_simple']['enabled'] is defined) and (pillar['ufw_simple']['enabled'] is not none) and (pillar['ufw_simple']['enabled']) %}
ufw_simple_update_deb:
  pkg.installed:
    - sources:
      - ufw: 'salt://ufw_simple/files/ufw_0.35-4_all.deb'

    # not managed nat - to be removed
    {%- if (pillar['ufw_simple']['nat_enabled'] is defined) and (pillar['ufw_simple']['nat_enabled'] is not none) and (pillar['ufw_simple']['nat_enabled']) %}
ufw_simple_nat_file_1:
  file.managed:
    - name: '/etc/ufw/sysctl.conf'
    - source: 'salt://ufw_simple/files/ufw_sysctl.conf'
    - mode: 0644

ufw_simple_nat_file_2:
  file.managed:
    - name: '/etc/default/ufw'
    - source: 'salt://ufw_simple/files/etc_default_ufw'
    - mode: 0644

ufw_simple_restart:
  cmd.run:
    - name: 'ufw disable && sleep 5 && ufw enable'
    - runas: root
    - onchanges:
      - file: '/etc/ufw/sysctl.conf'
      - file: '/etc/default/ufw'
    {%- endif %}

    # managed nat
    {%- if
           (pillar['ufw_simple']['nat'] is defined) and (pillar['ufw_simple']['nat'] is not none) and
           (pillar['ufw_simple']['nat']['enabled'] is defined) and (pillar['ufw_simple']['nat']['enabled'] is not none) and (pillar['ufw_simple']['nat']['enabled'])
    %}
ufw_simple_nat_managed_file_1:
  file.managed:
    - name: '/etc/ufw/sysctl.conf'
    - source: 'salt://ufw_simple/files/ufw_sysctl.conf'
    - mode: 0644

ufw_simple_nat_managed_file_2:
  file.managed:
    - name: '/etc/default/ufw'
    - source: 'salt://ufw_simple/files/etc_default_ufw'
    - mode: 0644

ufw_simple_nat_managed_file_3:
  file.managed:
    - name: '/etc/ufw/before.rules'
    - source: 'salt://ufw_simple/files/before.rules'
    - mode: 0640
    - template: jinja
    - defaults:
      {%- if (pillar['ufw_simple']['nat']['masquerade'] is defined) and (pillar['ufw_simple']['nat']['masquerade'] is not none) %}
        masquerade: |
        {%- for m_item in pillar['ufw_simple']['nat']['masquerade']['source']|sort %}
          -A POSTROUTING -s {{ m_item }} -o {{ pillar['ufw_simple']['nat']['masquerade']['out'] }} -j MASQUERADE
        {%- endfor %}
      {%- else %}
        masquerade: '# empty'
      {%- endif %}
      {%- if (pillar['ufw_simple']['nat']['dnat'] is defined) and (pillar['ufw_simple']['nat']['dnat'] is not none) %}
        dnat: |
        {%- for d_key, d_val in pillar['ufw_simple']['nat']['dnat']['destination'].items()|sort %}
          -A PREROUTING -i {{ pillar['ufw_simple']['nat']['dnat']['in'] }} -p {{ d_val['proto'] }} --dport {{ d_key }} -j DNAT --to-destination {{ d_val['to'] }}
        {%- endfor %}
      {%- else %}
        dnat: '# empty'
      {%- endif %}

ufw_simple_nat_managed_restart:
  cmd.run:
    - name: 'ufw disable && sleep 5 && ufw enable'
    - runas: root
    - onchanges:
      - file: '/etc/ufw/sysctl.conf'
      - file: '/etc/default/ufw'
      - file: '/etc/ufw/before.rules'
    {%- endif %}

    {%- if  (pillar['ufw_simple']['logging'] is defined) and (pillar['ufw_simple']['logging'] is not none) %}
ufw_simple_set_logging:
  cmd.run:
    - name: {{ 'ufw logging ' ~ pillar['ufw_simple']['logging'] }}
    - runas: root
    {%- endif %}

    {%- if  (pillar['ufw_simple']['allow'] is defined) and (pillar['ufw_simple']['allow'] is not none) %}
      {%- for item_name, item_params in pillar['ufw_simple']['allow'].items() %}
        {%- if (item_params['from'] is defined) and (item_params['from'] is not none) %}
          {%- set item_from = item_params['from'] %}
        {%- else %}
          {%- set item_from = {'any': 'any'} %}
        {%- endif %}
        {%- if (item_params['to'] is defined) and (item_params['to'] is not none) %}
          {%- set item_to = item_params['to'] %}
        {%- else %}
          {%- set item_to = {'any': 'any'} %}
        {%- endif %}
        {%- set i_loop = loop %}
        {%- for i_from in item_from %}
          {%- set j_loop = loop %}
          {%- for i_to in item_to %}
ufw_simple_allow_rule_{{ i_loop.index }}_{{ j_loop.index }}_{{ loop.index }}:
  cmd.run:
    - name: {{ 'ufw allow proto ' ~ item_params['proto'] ~ ' from ' ~ item_from[i_from] ~ ' to ' ~ item_to[i_to] ~ ' port ' ~ item_params['to_port'] ~ ' comment \'' ~ item_name ~ ' from ' ~ i_from ~ ' to ' ~ i_to ~ '\'' }}
    - runas: root
          {%- endfor %}
        {%- endfor %}
      {%- endfor %}
    {%- endif %}

ufw_simple_enable:
  cmd.run:
    - name: 'ufw enable'
    - runas: root

  {%- endif %}
{% endif %}