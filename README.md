echo router1 router2  | tr " " "\n" | xargs -P2 -I {} vagrant up {}<br/>
echo dc1 dc2 dc3 | tr " " "\n" | xargs -P5 -I {} vagrant up {}<br/>
echo ws1 ws2 | tr " " "\n" | xargs -P5 -I {} vagrant up {}<br/>
