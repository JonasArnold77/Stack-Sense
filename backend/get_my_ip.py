import urllib.request
ip = urllib.request.urlopen('https://api.ipify.org').read().decode()
print('Deine aktuelle öffentliche IP:', ip)
print(f'Diese IP muss in der RDS Security Group als Inbound Rule stehen (Port 5432)')
