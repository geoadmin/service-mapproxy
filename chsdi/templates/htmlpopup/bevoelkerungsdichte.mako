<%inherit file="base.mako"/>

<%def name="table_body(c, lang)">
    <tr><td width="150">${_('einwohner_ha')}</td>   <td>${int(round(c['attributes']['popt_ha']) or '-'}</td></tr>
    <tr><td width="150">${_('stand')}</td>          <td>${int(round(c['attributes']['stand'])) or '-'}</td></tr>
</%def>
