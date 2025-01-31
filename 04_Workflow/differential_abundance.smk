rule taxa_collapse:
    input:
        rarefactionfiltertable = OUTPUTDIR + "/04_taxonomy/" + PROJ + "-rarefaction-table-filtered-" + GROUP + ".qza",
        sklearn = OUTPUTDIR + "/04_taxonomy/" + PROJ + "-tax_sklearn.qza",
    output:
        table_collapse = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-collapse-table-" + GROUP + ".qza",
    log:
        LOGDIR + "/07_differential_abundance/" + PROJ + "_" + GROUP + "-taxa_collapse.log"
    params:
        level = config["ancom"]["taxa_level"]
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        qiime taxa collapse \
        --i-table {input.rarefactionfiltertable} \
        --i-taxonomy {input.sklearn} \
        --p-level {params.level} \
        --o-collapsed-table {output.table_collapse}
        """

rule visualization_taxa_collapse:
    input:
        table_collapse = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-collapse-table-" + GROUP + ".qza",
    output:
        table_collapse_viz = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-collapse-table-" + GROUP + ".qzv",
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        qiime metadata tabulate \
        --m-input-file {input.table_collapse} \
        --o-visualization {output.table_collapse_viz}
        """

# ## To process the frequency filtering by group of samples : split the feature-table for each group
rule filter_group:
    input:
        table_collapse = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-collapse-table-" + GROUP + ".qza"
    output:
        output_table_split = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_split-" + GROUP + ".txt"
    params:
        group = GROUPCONDITION,
        table_split = expand(OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_split-{group}-" + GROUP + ".qza", group=GROUPCONDITION),
        table_split_viz = expand(OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_split-{group}-" + GROUP + ".qzv", group=GROUPCONDITION),
        metadata = ROOTDIR + METADATA
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        table_split=({params.table_split})
        group=({params.group})
        len=${{#group[@]}}
        for (( i=0; i<$len; i=i+1 ))
        do qiime feature-table filter-samples \
        --i-table {input.table_collapse} \
        --m-metadata-file {params.metadata} \
        --p-where "group_experiment = '${{group[$i]}}'" \
        --o-filtered-table ${{table_split[$i]}}
        done
        echo "split_group DONE" > {output.output_table_split}
        """

## Frequency filtering of each feature-table corresponding to the different group of samples
rule filter_features:
    input:
        table_split = expand(OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_split-{group}-" + GROUP + ".qza", group=GROUPCONDITION),
    output:
        output_table_filtered = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_filtered-" + GROUP + ".txt"
    params:
        group = GROUPCONDITION,
        table_filtered = expand(OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_filtered-{group}-" + GROUP + ".qza", group=GROUPCONDITION),
        metadata = ROOTDIR + METADATA
    log:
        LOGDIR + "/07_differential_abundance/" + PROJ + "_" + GROUP + "-filter_features.log"
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        table_split=({input.table_split})
        table_filtered=({params.table_filtered})
        group=({params.group})
        len=${{#table_split[@]}}
        for (( i=0; i<$len; i=i+1 ))
        do qiime feature-table filter-features \
        --i-table ${{table_split[$i]}} \
        --p-min-frequency {config[ancom][min_frequency]} \
        --p-min-samples {config[ancom][min_sample]} \
        --o-filtered-table ${{table_filtered[$i]}}
        done
        echo "filter_group DONE" > {output.output_table_filtered}
        """

## Merge the feature table which has been filtered independantly
## LA voir comment mettre la list en shell
rule merge_feature_table:
    input:
        table_filtered = expand(OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_filtered-{group}-" + GROUP + ".qza", group=GROUPCONDITION),
    output:
        output_table_merged = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_merged-" + GROUP + ".txt",
        table_merged = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_merged-" + GROUP + ".qza",
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        table_filtered=({input.table_filtered})
        table_merged=({output.table_merged})
        len=${{#table_filtered[@]}}
        list_table_filtered=("/media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-16_PP_villi-dada2.qza
 /media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-19_PP_villi-dada2.qza /media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-21_PP_villi-dada2.qza /media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-23_PP_villi-dada2.qza /media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-25_PP_villi-dada2.qza /media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-28_PP_villi-dada2.qza /media/thomas/data/tomas_weaning_011222/05_Output/07_differential_abundance/weaning-table_filtered-49_PP_villi-dada2.qza")
        qiime feature-table merge \
        --i-tables ${{list_table_filtered}} \
        --o-merged-table ${{table_merged}}
        echo ${{list_table_filtered}} >> {output.output_table_merged}
        """

rule visualization_merge_feature_table:
    input:
        table_merged = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_merged-" + GROUP + ".qza"
    output:
        output_visualization_feature_table = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_merged-" + GROUP + ".qzv"
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        qiime metadata tabulate \
        --m-input-file {input.table_merged} \
        --o-visualization {output.output_visualization_feature_table}
        """

rule filter_sample:
    input:
        table_merged = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table_merged-" + GROUP + ".qza",
    output:
        table_abond_selectedsample = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table-abund-selectedsample-" + GROUP + ".qza",
        table_abond_qzv = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table-abund-selectedsample-" + GROUP + ".qzv"
    params:
        metadata = ROOTDIR + RMSAMPLE
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        qiime feature-table filter-samples \
        --i-table {input.table_merged} \
        --m-metadata-file {params.metadata}\
        --p-exclude-ids True \
        --o-filtered-table {output.table_abond_selectedsample}
        qiime metadata tabulate --m-input-file {output.table_abond_selectedsample} --o-visualization {output.table_abond_qzv}
        """

############################

rule pseudocount:
    input:
        table_abond_selectedsample = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table-abund-selectedsample-" + GROUP + ".qza"
    output:
        table_abond_comp = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table-abund-comp-" + GROUP + ".qza"
    log:
        LOGDIR + "/07_differential_abundance/" + PROJ + "_" + GROUP + "-pseudocount.log"
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        qiime composition add-pseudocount \
        --i-table {input.table_abond_selectedsample} \
        --o-composition-table {output.table_abond_comp}
        """

## LA FAIRE LES GROUPES POUR COMPARAISON DEUX A DEUX (demander à Julie)
rule ancom:
    input:
        table_abond_comp = OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-table-abund-comp-" + GROUP + ".qza"
    output:
        ancom = report(expand(OUTPUTDIR + "/07_differential_abundance/" + PROJ + "-ancom-{column}-" + GROUP + ".qzv", column=COLUMN), caption = ROOTDIR + "/07_Report/ancom.rst", category="07 differential abundance")
    params:
        column = COLUMN,
        metadata = ROOTDIR + "/sample-metadata.tsv"
    log:
        LOGDIR + "/07_differential_abundance/" + PROJ + "_" + GROUP + "-ancom.log"
    conda:
        ROOTDIR + "/02_Container/qiime2.yaml"
    shell:
        """
        conditions=({output.ancom})
        column=({params.column})
        len=${{#column[@]}}
        for (( i=0; i<$len; i=i+1 ))
        do qiime composition ancom \
        --i-table {input.table_abond_comp} \
        --m-metadata-file {params.metadata} \
        --m-metadata-column ${{column[$i]}} \
        --o-visualization ${{conditions[$i]}}
        done
        """
