#!/usr/bin/env nextflow
// -*- mode: groovy; -*-

/* ============================================================
 Train neural network
 ============================================================ */


params.numEpochs = 5
params.config = "$baseDir/examples/all.yaml"
params.trainingData =""
params.checkData = false


training_data_ch = Channel.fromPath(params.trainingData)

if (! params.checkData) {

    checked_data_ch = Channel.fromPath(params.trainingData)

} else {

    process checkData {
        input:
            file x from training_data_ch
        output:
            file x into checked_data_ch
    """
    python -m uwnet.check_data $x
    """

    }
}

scm_data_ch = Channel.fromPath(params.trainingData)
case_ch = Channel.fromPath("$baseDir/assets/NG1/")

/*
 Train the Neural network
 */


process trainModel {
  publishDir "data/models/"
  input:
  file x from checked_data_ch

  output:
        file '*.pkl' into single_column_mode_ch, sam_run_ch

  """
  python -m uwnet.train  -n $params.numEpochs -lr .005 -s 5 -l 20 \
         $params.config $x
  """
}

/*

 Criticism of the trained neural network

 1. Perform single column model simulation
 */

process runSingleColumnModel {
  input:
  file model from single_column_mode_ch
  file data from scm_data_ch

  output:
  file 'cols.nc' into single_column_ch


  """
  python -m uwnet.columns ${model.last()} $data cols.nc
  """
}

/*
 Visualize the trained model results
 */

process plotPrecipTropics {
   publishDir "data/plots/"
   input:
   file sim from single_column_ch

   output:
   file '*.png'

  """
  #!/usr/bin/env python
  import xarray as xr
  import matplotlib.pyplot as plt
  g = xr.open_dataset("$sim") #.swap_dims({'z': 'p'})

  for j in [32, 20, 10]:
      plt.figure()
      g['Prec'][:,j,0].plot()
      g['PrecOBS'][:,j,0].plot()
      plt.savefig(f"prec_{j}.png")



      for key in ['QT', 'SLI', 'QN', 'QP']:
          plt.figure()
          qt = g[key][:,:,j, 0]
          qt.plot.contourf(x='time')
          plt.savefig(f"{key}_{j}.png")

          plt.figure()
          qt = g[key][:,5,j, 0]
          plt.plot(g.time, qt)
          plt.savefig(f"{key}_{j}_z5.png")

  """

}


/*
 Run the neural network with SAM
 */
process runSAMNeuralNetwork {
    publishDir "data/samNN/$workflow.runName"
    validExitStatus 0,9
    afterScript "rm -rf   RUNDATA RESTART "
    input:
        file(x) from sam_run_ch.flatten().last()
    file 'NG1' from case_ch

    output:
        file 'OUT_3D/*.nc'
        file 'OUT_2D/*.nc'
        file 'OUT_STAT/*.nc'
        // set file('NG1/data.pkl'), file('*.pkl' ) into check_sam_dbg_ch

    """
    run_sam_nn_docker.sh $x $baseDir/assets/NG1
    """
}

// process checkSAMNN {
//     publishDir "data/samNN/$workflow.runName/"
//     input:
//         set file(model), file(x) from check_sam_dbg_ch
//     output:
//         file 'sam_nn.txt'
//     when:
//         false
//     """
//     for file in $x
//     do
//         echo "Checking Water budget for \$file" >> sam_nn.txt
//         check_sam_nn_debugging.py \$file $model >> sam_nn.txt
//         echo
//     done
//     """

// }
