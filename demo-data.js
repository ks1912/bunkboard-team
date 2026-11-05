/* Shared demo data for owner-demo.html and find-pg.html (all fictional) */
const PRICE={1:14000,2:9500,3:7500,4:6000};
function seed(){
  // 5 floors: 6,6,6,4,4 rooms -> 2 single, 5 double, 10 triple, 9 quad (26 rooms, 78 beds)
  const plan=[[4,4,4,3,3,3],[4,4,4,3,3,3],[4,4,4,3,3,3],[3,2,2,2],[1,1,2,2]];
  const rooms=[];
  plan.forEach((types,fi)=>types.forEach((t,i)=>rooms.push({id:(fi+1)*100+i+1,floor:fi+1,type:t,price:PRICE[t]})));
  let s=7;const rnd=()=>(s=(s*16807)%2147483647)/2147483647;
  const F=['Priya','Ananya','Sneha','Divya','Meghana','Kavya','Lakshmi','Pooja','Harini','Swathi','Nikitha','Bhavana','Ramya','Sirisha','Tejaswini','Anusha','Keerthi','Manasa','Sowmya','Pavani','Aishwarya','Neha','Shruti','Vaishnavi'];
  const Lh=['Reddy','Sharma','Naidu','Rao','Kumari','Goud','Patel','Singh','Iyer','Verma','Varma','Chowdary'];
  const res=[];let id=1,n=0;
  rooms.forEach(r=>{for(let b=0;b<r.type;b++){
    if(rnd()<0.74){
      const roll=rnd(),late=roll>.8;let cash=0,upi=0;
      if(roll<.55){const u=rnd()<.7;if(u)upi=r.price;else cash=r.price}
      else if(roll<.62){upi=Math.round(r.price/2)}
      res.push({id:id++,name:F[n%F.length]+' '+Lh[(n*5+3)%Lh.length],phone:'9000'+String(10000+n*37).slice(-5)+'1',room:r.id,bed:b,rent:r.price,cash,upi,late:late&&cash+upi<r.price,sent:false});
      n++;
    }}});
  const staff=[{id:1,name:'Saroja',role:'Cook',salary:18000,paid:true},{id:2,name:'Mallesh',role:'Cleaner',salary:12000,paid:true},{id:3,name:'Rukmini',role:'Cleaner',salary:12000,paid:false},{id:4,name:'Bhaskar',role:'Security',salary:15000,paid:false}];
  const lic={trade:{s:'have',d:140},fire:{s:'have',d:24},building:{s:'have',d:900},police:{s:'applied'},fssai:{s:'have',d:300},labour:{s:'none'}};
  return {lang:'en',tab:'overview',open:{1:true},rooms,res,staff,lic,safe:{cctv:1,ext:1,exit:1,aid:1,reg:1,ward:0,elec:0},dp:{consent:0,notice:0,cctvp:0},nextRes:id,nextStaff:5,nextRoom:900};
}
