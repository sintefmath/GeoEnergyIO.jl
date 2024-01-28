g = oneSlopingFault([2, 2, 2], 5);
G = processGRDECL(g);
writeGRDECL(g,'sloped.txt');

figure; plotGrid(G)
%%
g = raisedColumn()
G = processGRDECL(g)
figure; plotGrid(G)
writeGRDECL(g,'raised_col.txt');
%%
g = createPinchedColumn()
G = processGRDECL(g)
figure; plotGrid(G)
%%
g = pinchedLayersGrdecl([2, 2, 2])
G = processGRDECL(g)
figure; plotGrid(G)
%%
g = oneSlopingFault([10, 20, 20], 5)
G = processGRDECL(g)
figure; plotGrid(G)
%%
dims = [5, 5, 3]
g = makeModel3(dims)
G = processGRDECL(g)
figure; plotGrid(G)
%%
close all
   [x, y, z] = ndgrid(0 : 2, 0 : 1, 0);
   coord     = repmat([x(:), y(:), z(:)], [1, 2]);

   zcorn = ...
      [  0 0 , 0   0   ; ...
         0 0 , 0   0   ; ...
         1.6 1.6 , 0.5 0.5 ; ...
         1 1 , 0.5 0.5 ; ...
                         ...
         1.6 1.6 , 0.5 0.5 ; ...
         1 1 , 0.5 0.5 ; ...
         2 2 , 1.5 1.5 ; ...
         2 2 , 1.5 1.5 ; ...
      ];

   grdecl = struct('cartDims', [2, 1, 2], ...
                   'COORD'   , reshape(coord .', [], 1), ...
                   'ZCORN'   , reshape(zcorn .', [], 1));
G = processGRDECL(grdecl)
figure; %
for i = 1:G.cells.num
    plotGrid(G, i, 'facea', .2)
end
xlabel('X')

writeGRDECL(grdecl,'raised_col_sloped.txt');
%%
grdecl = cartesianGrdecl(0:1, 0:1, 0:1);
writeGRDECL(grdecl,'1cell.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
grdecl = cartesianGrdecl(0:1, 0:1, 0:3);
writeGRDECL(grdecl,'1col.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
grdecl = cartesianGrdecl(0:2, 0:1, 0:3);
writeGRDECL(grdecl,'2col.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
grdecl = makeModel3([5, 5, 5])
writeGRDECL(grdecl,'model3_5_5_5.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
grdecl = makeModel3([20, 20, 50])
writeGRDECL(grdecl,'model3_20_20_50.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
grdecl = makeModel3([2, 3, 5])
writeGRDECL(grdecl,'model3_abc.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
%%
grdecl = makeModel3([1, 1, 5])
writeGRDECL(grdecl,'.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
for i = 1:4
    grdecls = pinchMiddleCell(i);
    for j = 1:numel(grdecls)
        grdecl = grdecls{j};
        writeGRDECL(grdecl,[num2str(i), '_', num2str(j), '_node_pinch.txt']);
        figure; plotGrid(processGRDECL(grdecl));
    end
end
%%
grdecl = pinchedLayersGrdecl([4, 4, 4], 0.1)
writeGRDECL(grdecl,'pinched_layers_5_5_5.txt');
figure; plotGrid(processGRDECL(grdecl));
%%
A = [ 1.568      0.76193   0.577016  0.978997   0.0       0.861418   0.45678    0.1903    0.0       0.500341   0.633684   0.502301   0.237463   0.0642981
 0.591522   1.69643   0.0       0.82597    0.805336  0.531948   0.402032   0.578964  0.115015  0.586036   0.374429   0.467703   0.428681   0.0
 0.34942    0.83851   1.33304   0.283348   0.60722   0.823428   0.966299   0.78599   0.649946  0.0        0.346478   0.261765   0.359136   0.9404
 0.772925   0.704776  0.288261  1.67061    0.0       0.222113   0.428867   0.0       0.0       0.777237   0.984521   0.302067   0.0        0.952114
 0.489546   0.91913   0.0       0.913744   1.0       0.0        0.499313   0.0       0.85725   0.928452   0.975571   0.645395   0.530002   0.0
 0.24606    0.536933  0.949442  0.769587   0.0       1.84502    0.422534   0.985667  0.0       0.511815   0.217525   0.303688   0.893191   0.0
 0.678847   0.0       0.0       0.915233   0.0       0.551624   1.65054    0.793549  0.282171  0.232682   0.955199   0.293391   0.216064   0.0
 0.347392   0.513552  0.0       0.92009    0.538017  0.760893   0.396753   1.0       0.0       0.73126    0.0370283  0.97207    0.972966   0.0
 0.962793   0.708944  0.557088  0.0544357  0.126918  0.369881   0.232172   0.176908  1.33848   0.0        0.534251   0.628057   0.571644   0.589601
 0.0        0.301387  0.452369  0.0        0.502427  0.0        0.0        0.88537   0.647265  1.10852    0.925766   0.0        0.693945   0.0372478
 0.176002   0.0       0.351328  0.282251   0.250336  0.808999   0.0585666  0.646603  0.188341  0.680903   1.0        0.594446   0.0949512  0.595118
 0.160477   0.160888  0.602538  0.697394   0.325953  0.430759   0.0        0.83129   0.669542  0.0509715  0.436533   1.62086    0.0        0.154293
 0.0636402  0.0       0.450466  0.0818475  0.218832  0.0302217  0.0        0.562064  0.4815    0.783092   0.7439     0.532014   1.20238    0.0154605
 0.221292   0.313392  0.224786  0.328214   0.2565    0.440086   0.898817   0.2093    0.0       0.0        0.580937   0.0571966  0.802766   1.11897]