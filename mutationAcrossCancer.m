%% Cancer Gene Mutation Frequecies and Variantion in 55 Cancer Types

% From the compendium paper: As new snapshots of the compendium are
% uncovered with use of these data, the trend described above is predicted
% to continue into the future, with the identification of (1) new drivers
% mutated at frequencies below 10% across malignancies (owing to increased
% statistical power96), (2) drivers of conditions not profiled before, (3)
% drivers in diverse populations or ethnicities that have so far been
% biased against in tumour genome sequencing projects and (4) drivers of
% new clinical entities, such as metastatic or relapse tumours, which have
% been comparatively underexplored to date.

% Driver genes in diverse populations and/or ethnicities

% % change the directory and clear everthing
% try
%     cd '/Users/sinkala/Documents/MATLAB/cancerUKB_snps'
% catch
%     cd '/scratch/snkmus003/cancerMuts/'
% end

% make a directory if it does not exist
if ~exist('allCancerMutations','dir')
    mkdir allCancerMutations
    addpath('/allCancerMutations')
end

% % add the path to matlab and change the directory
% addpath('/Users/sinkala/Documents/MATLAB/cancerUKB_snps/allCancerMutations')
% addpath('/scratch/snkmus003/cancerMuts/allCancerMutations')

% have a new slate 
clear; close all force; clc;

% disable all warmings so it is easy to debug the code 
warning('off','all')
warning

%% Get the Know Cancer Genes

% check that the cancer genes information file exist if not process data 
if ~exist('cancer_genes_info.csv','file')
    
    % print something to the screen 
    fprintf('\nNow processing the cancer gene information \n')
    
    % here are the consuss cancer genes
    cancerGC1 = readtable('Census_allMon Apr 18 09_07_15 2022.csv') ;
    cancerGC2 = readtable('Census_allMon Apr 18 09_07_31 2022.csv') ;
    cancerGC2.Hallmark = cellstr(num2str(cancerGC2.Hallmark)) ;
    cancerGC = [cancerGC1; cancerGC2] ;
    
    % load the cancer genes 
    cosmic = cancerGC;
    cosmicOGs = cosmic.GeneSymbol(contains(cosmic.RoleInCancer,'oncogene'));
    cosmicTSG = cosmic.GeneSymbol(contains(cosmic.RoleInCancer,'TSG'));
    uniprot_OGs = readtable('uniprot_protooncogene.xlsx');
    uniprot_TSGs = readtable('uniprot_TSGs.xlsx');
    TSGenes = readtable('Human_TSGs.txt');
    ONCOgenes = readtable('ONCOgenes_human.txt');
    
    % we put together the oncogenes and TSGs
    oncogenes = unique( [cosmicOGs; ...
        extractBefore(uniprot_OGs.EntryName,'_') ; ONCOgenes.OncogeneName ] );
    TSGs = unique( [cosmicTSG ; extractBefore(uniprot_TSGs.EntryName,'_') ; ...
        TSGenes.Var2(2:end) ] );
    
    % remove the oncogenes that are also indicated as tumours supperssor genes
    oncogenes(ismember( oncogenes ,{'TP53','PTEN'} )) = [] ;
    TSGs(ismember(TSGs, {'TP63','TPM3'})) = [] ;
    
    % ****************** get the other genes ********************
    cosmicOther = unique( cosmic.GeneSymbol(...
        ~contains(cosmic.RoleInCancer,{'oncogene','TSG'}) ) );
    cosmicOther = setdiff( setdiff(cosmicOther,  oncogenes), TSGs);
    
    % put these in the sample table
    cancerGenes = table( [ oncogenes;TSGs;cosmicOther ] , ...
        [ repmat( {'Oncogenes'}, length(oncogenes) , 1 ) ; ...
        repmat( {'TSGs'}, length(TSGs) ,1); ...
        repmat( {'Other'}, length(cosmicOther) ,1) ] , ...
        'VariableNames' , {'HugoSymbol','RoleInCancer'} ) ;
    
    % ***** get kinases and phosphatases and add them to the table ******
    kea = readtable('KEA_2015.xlsx','Format','auto',...
        'ReadVariableNames',false);
    
    % get only the first column of the data and add kinase to the table
    kea = addvars( kea(:,1) ,repmat({'Kinases'},height(kea),1) ) ;
    kea.Properties.VariableNames = {'HugoSymbol','Kinase_PPtase'} ;
    
    % here are the phosphases
    pps = readtable('Phosphatase_Substrates_from_DEPOD.txt',...
        'Format','auto','ReadVariableNames',false) ;
    pps = addvars( pps(:,1) ,repmat({'Phosphatases'},height(pps),1) ) ;
    pps.Properties.VariableNames = {'HugoSymbol','Kinase_PPtase'} ;
    
    % combine the kinases and phosphatases
    kea = [kea; pps] ;
    
    % add the kinases to the cancer genes
    cancerGenes = outerjoin(cancerGenes,kea,'MergeKeys',true);
    cancerGenes.Kinase_PPtase(ismissing(cancerGenes.Kinase_PPtase)) = ...
        {'Other'} ;
    
    % ************* also add transcription factors to the table **********
    chea = readtable('ChEA_2016.xlsx','Format','auto',...
        'ReadVariableNames',false);
    chea = chea(:,1) ;
    chea.Var1 = extractBefore(chea.Var1,'_') ;
    
    % get the transcription factors from the other database
    tfs = readtable( ...
        'all_transcription_factors.csv','ReadVariableNames',false);
    
    % make one table 
    chea = unique([chea; tfs]) ;

    % get only the first column of the TFs and add TF name to the table
    chea = addvars( chea ,repmat({'TFs'},height(chea),1) ) ;
    chea.Properties.VariableNames = {'HugoSymbol','TF'} ;
    cancerGenes = outerjoin(cancerGenes,chea,'MergeKeys',true);
    cancerGenes.TF(ismissing(cancerGenes.TF)) = {'Other'} ;
    
    % ******************* add receptors to the table *******************
    receptors = readtable("cell_surface_receptors.csv");
    receptors = addvars( receptors(:,2) , ...
        repmat({'Receptors'},height(receptors),1) ) ;
    receptors.Properties.VariableNames = {'HugoSymbol','Location'} ;
    
    % return only the receptors that
    receptors(~ismember(receptors.HugoSymbol,cancerGenes.HugoSymbol),:) = [];
    
    % now add these to the table
    cancerGenes = outerjoin(cancerGenes,receptors,'MergeKeys',true);
    cancerGenes.Location(ismissing(cancerGenes.Location)) = {'Other'} ;
    
    % remove the bad genes from the data 
    cancerGenes.HugoSymbol = regexprep(cancerGenes.HugoSymbol, ...
        {'\-+\w*'} ,'') ;
    
    % get only the unique genes
    cancerGenes = unique(cancerGenes) ;
    cancerGenes(ismissing(cancerGenes.HugoSymbol), :) = [] ;
    
    % add the other list of the cancer genes
    cancerGenes.RoleInCancer(ismissing(cancerGenes.RoleInCancer)) = ...
        {'Other'} ;
    cancerGenes.Kinase_PPtase(ismissing(cancerGenes.Kinase_PPtase)) = ...
        {'Other'} ;
    
    % ********************************************************************
    % here are the consuss cancer genes
    cancerGenes = cancerGenes( ismember( cancerGenes.HugoSymbol, ...
        cancerGC.GeneSymbol), :) ;
    
    % ********************************************************************
    
    % save the file to a .csv file
    writetable(cancerGenes,'cancer_genes_info.csv')
else
    % load the processed data
    cancerGenes = readtable('cancer_genes_info.csv') ;
end

clear ans cosmic cosmicOGs cosmicTSG ONCOgenes TSGs uniprot_OGs ...
    uniprot_TSGs TSGenes oncogenes receptors chea kea pps cancerGC1 ...
    cancerGC2 cosmicOther

%% Download the datasets

if exist('all_ccg_mutations.mat','file')
    fprintf('\n Loading the mutations data\n')
    % this data has matched results load mapkData.mat
    
    % this dataset contains all the mutations
    load 'all_ccg_mutations.mat'
    
    % error('Get the more than 40000 data from cBioPortal')
else
    fprintf(['\nGetting cBioPortal Data from http:/',...
        '/www.cbioportal.org/public-portal\n'])
    
    % set the bias of the: because mutation have more data. I will get all
    % data that has mutation data here
    mutBias = true;
    
    % here are the genes
    myGenes = unique(cancerGenes.HugoSymbol) ;
    
    % get the data from the cBioPortal online repository
    [mutations,mafFile,cancerStudies,clinicalData ] = ...
        getcBioPortalDataAllStudies(myGenes,mutBias) ;
    
    % change the CancerStudy to Upper
    mutations.CancerStudy = upper(mutations.CancerStudy);
    
    % remove the duplicate sample Ids from the mutations data, copy
    % number data and the clinical data
    [~, theUnique] = unique(mutations.SampleIds);
    mutations = mutations(theUnique,:);
    
    % save the mutation baised data
    fprintf('\nSaving the processed mutation data \n')
    save('all_ccg_mutations.mat','mutations','mafFile','clinicalData',...
        'cancerStudies','missingGenes')
end

%% Clean Up the Data

fprintf('\n Cleaning the clinical and mutation data \n')

% load 'all_ccg_mutations.mat'

clinicalData.Properties.VariableNames(1) = "SampleIds" ;
clinicalData.OncoTreeCode = categorical(clinicalData.OncoTreeCode) ;

% remove the undefined categories from the data 
clinicalData(isundefined(clinicalData.OncoTreeCode), :) = [] ;
mutations(isundefined(mutations.CancerStudy),:) = [] ;

% replace the - with _
clinicalData.SampleIds = replace(clinicalData.SampleIds,'-','_');
mutations.SampleIds = replace(mutations.SampleIds,'-','_');

% strip the samples ids 
clinicalData.SampleIds = strtrim(clinicalData.SampleIds);
mutations.SampleIds = strtrim(mutations.SampleIds) ;

% **********************************************************************
% There is a problem with some samples Ids that are not correctly formated
% I should correct most of those manually 

% Remove the mestatics studies from teh data 
mutations(ismember(mutations.CancerStudy,{'METASTATIC','MSK'}),:) = [] ;

% find the location of the TCGA samples in both dataset and change reduce
% the length of those strings - This takes care of the TCGA samples
mutations.SampleIds( contains(mutations.SampleIds,'TCGA', ...
    'IgnoreCase',true)) = extractBefore( ...
    mutations.SampleIds( contains(mutations.SampleIds,'TCGA', ...
    'IgnoreCase',true)),13) ;

clinicalData.SampleIds( contains(clinicalData.SampleIds,'TCGA', ...
    'IgnoreCase',true)) = extractBefore( ...
    clinicalData.SampleIds( contains(clinicalData.SampleIds,'TCGA', ...
    'IgnoreCase',true)),13) ;

% Clean up the variable names for the UTCC cancer by shorting the string to
% in the mutation data to match those in the clinical data 
mutations.SampleIds( contains(mutations.SampleIds,'DS_uttcc', ...
    'IgnoreCase',true)) = extractBefore( ...
    mutations.SampleIds( contains(mutations.SampleIds,'DS_uttcc', ...
    'IgnoreCase',true)), '_P') ;

% change the samples of the prostate cancer samples 'ICGC_PCA' 'ICGC_PCA164_T01'
mutations.SampleIds( contains(mutations.SampleIds,'ICGC_PCA', ...
    'IgnoreCase',true)) = extractBefore( ...
    mutations.SampleIds( contains(mutations.SampleIds,'ICGC_PCA', ...
    'IgnoreCase',true)), '_T01') ;

% change the samples of the prostate cancer samples 'ICGC_CLL' 'ICGC_PCA164_T01'
mutations.SampleIds( contains(mutations.SampleIds,'ICGC_CLL', ...
    'IgnoreCase',true)) = extractBefore( ...
    mutations.SampleIds( contains(mutations.SampleIds,'ICGC_CLL', ...
    'IgnoreCase',true)), {'_TD'}) ;

% remove the PRAD samples that are not profiled by the TCGA 
nonTCGAprad = mutations.CancerStudy == "PRAD" & ...
    ~contains(mutations.SampleIds,'TCGA') ;
mutations(nonTCGAprad,:) = [] ;

% change the samples of the AML samples {'aml_ohsu_2018_16_00731'} to match
% the clinical data {'aml_ohsu_2018_1998'}
mutations.SampleIds( contains(mutations.SampleIds,'aml_ohsu_2018', ...
    'IgnoreCase',true)) = replace( ...
    mutations.SampleIds( contains(mutations.SampleIds,'aml_ohsu_2018', ...
    'IgnoreCase',true)), '_16_', '_') ;

% only return the samples ids with mutations in the maf file 
mafFile = movevars( mafFile,'Tumor_Sample_Barcode',...
    'After','CancerStudy') ;
mafFile.Properties.VariableNames(2) = "SampleIds" ;
mafFile.SampleIds = replace( mafFile.SampleIds,'-','_') ;

% Clean up the variable names for the UTCC cancer by shorting the string to
% in the mutation data to match those in the clinical data 
mafFile.SampleIds( contains(mafFile.SampleIds,'DS_uttcc', ...
    'IgnoreCase',true)) = extractBefore( ...
    mafFile.SampleIds( contains(mafFile.SampleIds,'DS_uttcc', ...
    'IgnoreCase',true)), '_P') ;

% change the samples of the prostate cancer samples 'ICGC_PCA' 'ICGC_PCA164_T01'
mafFile.SampleIds( contains(mafFile.SampleIds,'ICGC_PCA', ...
    'IgnoreCase',true)) = extractBefore( ...
    mafFile.SampleIds( contains(mafFile.SampleIds,'ICGC_PCA', ...
    'IgnoreCase',true)), '_T01') ;

% change the samples of the prostate cancer samples 'ICGC_CLL' 'ICGC_PCA164_T01'
mafFile.SampleIds( contains(mafFile.SampleIds,'ICGC_CLL', ...
    'IgnoreCase',true)) = extractBefore( ...
    mafFile.SampleIds( contains(mafFile.SampleIds,'ICGC_CLL', ...
    'IgnoreCase',true)), {'_TD'}) ;

% change the samples of the AML samples {'aml_ohsu_2018_16_00731'} to match
% the clinical data {'aml_ohsu_2018_1998'}
mafFile.SampleIds( contains(mafFile.SampleIds,'aml_ohsu_2018', ...
    'IgnoreCase',true)) = replace( ...
    mafFile.SampleIds( contains(mafFile.SampleIds,'aml_ohsu_2018', ...
    'IgnoreCase',true)), '_16_', '_') ;

% finally return only the matching sample Ids 
mafFile = mafFile( ismember(mafFile.SampleIds,mutations.SampleIds), :) ;

% ************************* Return only the CGC ************************

% mafFile = mafFile( ismember( mafFile.Hugo_Symbol,cancerGC.GeneSymbol), :);
% mutations = [ mutations(:,[1,2]),  ...
%     mutations(:,ismember(mutations.Properties.VariableNames, ...
%     cancerGC.GeneSymbol) ) ];
% cancerGenes = cancerGenes( ismember( cancerGenes.HugoSymbol, ...
%     cancerGC.GeneSymbol), :) ;

% **********************************************************************

% return only the samples with more 30 samples do this in loop by removing
% samples from each dataset - Mutation and Clinical data until all have
% more than 30 samples for each class at a minimum
minCatClin = min(countcats(clinicalData.OncoTreeCode));
minCatMut = min(countcats(mutations.CancerStudy));
loopNumber = 1;

% here is  a while loop
while minCatClin < 30 || minCatMut < 100
    
    % printf something to the screen 
    fprintf('\nRunning analysis for loop # %d\n', loopNumber)
    
    % get the number of clinical samples
    numClinSamples = table(categories(clinicalData.OncoTreeCode), ...
        countcats(clinicalData.OncoTreeCode),'VariableNames', ...
        {'OncoTreeCode','Count'}) ;
    numClinSamples(numClinSamples.Count < 30,:) = [] ;
    
    % now return only those
    clinicalData = clinicalData(ismember(clinicalData.OncoTreeCode,...
        numClinSamples.OncoTreeCode), :) ;
    
    % return only the samples with more 30 samples
    numMutSamples = table( categories(mutations.CancerStudy), ...
        countcats(mutations.CancerStudy),'VariableNames', ...
        {'CancerStudy','Count'}) ;
    numMutSamples(numMutSamples.Count < 100,:) = [] ;
    
    % now only return those mutation
    mutations = mutations(ismember(mutations.CancerStudy,...
        numMutSamples.CancerStudy), :) ;
    
    % make sure that same Ids in the clinical data matches those in the
    % mutations data
    [~, locClin, locMut ] = intersect(clinicalData.SampleIds, ...
        mutations.SampleIds,'stable') ;
    clinicalData = clinicalData(locClin,:);
    mutations = mutations(locMut,:) ;
    
    % remove the categories with zero samples 
    clinicalData.OncoTreeCode =  ...
        categorical(cellstr(clinicalData.OncoTreeCode)) ;
    mutations.CancerStudy = categorical(cellstr(mutations.CancerStudy));
    
    % here is the min cat for both datasets 
    minCatClin = min(countcats(clinicalData.OncoTreeCode));
    minCatMut = min(countcats(mutations.CancerStudy));
    fprintf('\nThe min cat in Clin = %d and in Mut %d\n', ...
        minCatClin,minCatMut) 
    
    % count up the loop number 
    loopNumber = loopNumber + 1 ;
end

% throw in an assertion 
assert(all(strcmp(clinicalData.SampleIds,mutations.SampleIds)))

% return only the cancer studies present in the mutations data 
cancerStudies = cancerStudies( ismember(cancerStudies.cancerCode,...
    mutations.CancerStudy), :) ;

clear locClin locMut locOnco missingGenes ans minCatClin ii minCatMut ...
     loopNumber cancerGC1 cancerGC2

%% Continue with Cleaning up the data 

% some of the studies e.g THYROID and BREAST do not have oncotree
% annotations IDs therefore change these
changeCodes = {'LUNG','LUAD';'CRC','COADREAD';'THYROID','THAP';...
    'EGC','ESCA';'BREAST','BRCA';'PROSTATE','PRAD'; ...
    'Bladder Cancer','BLCA';'Breast Cancer','BRCA' ; ...
    'Colorectal Cancer','COADREAD'; 'Cancer of Unknown Primary',...
    'CUPNOS'; 'Esophagogastric Cancer','ESCA' ; ...
    'Glioma','GB'; 'Head and Neck Cancer','HNSC' ; ...
    'Non-Small Cell Lung Cancer','NSCLC' ;'COAD','COADREAD';...
    'Renal Cell Carcinoma','CCRCC';'Melanoma','SKCM'} ;
[locThem,these] = ismember(mutations.CancerStudy,changeCodes(:,1));
these(these == 0) = [] ;
mutations.CancerStudy(locThem) = changeCodes(these,2) ;

% throw in an assession
assert(all( strcmp(mutations.SampleIds, clinicalData.SampleIds) ))

clear catsIn numOfCats less10Samples checkO theUnique locThem these ...
    getCodes checkStudies

%% ====== get alterations of Each Gene and put them in one table ======

% create a table with two variable that are required by the function
% getAlterations frequency. One column should be the RoleInCancerName and the
% other should be Genes (which contains a list of gene that are involved in
% that MAPK RoleInCancer

% #######################################################################

% check that the data has already been processed
if exist('mutation_results.mat','file')
    % load the data
    load 'mutation_results.mat'
else
    
    % run the analysis in a loop
    for jj = 2:width(cancerGenes)
        
        % get the current gene types
        curGeneClass = cancerGenes.Properties.VariableNames{jj} ;
        
        fprintf('\nProcessing data for gene class %s number %d of %d\n',...
            curGeneClass, jj-1, width(cancerGenes)-1)
        
        % get the current data
        geneInClass = unique(cancerGenes.(curGeneClass));
        
        % if the data are categorical
        if iscategorical( geneInClass)
            geneInClass = cellstr(geneInClass) ;
        end
        
        % get all the genes and the class then put them in a table
        curGeneClassAlterations = cell( length(geneInClass),1 );
        for ii = 1:length(geneInClass)
            curGeneClassAlterations(ii,1) = geneInClass(ii);
            curGeneClassAlterations{ii,2} = ...
                strjoin( cancerGenes.HugoSymbol( ...
                ismember(cancerGenes.(jj),geneInClass(ii) ) )  );
        end
        
        % also add all the mapk RoleInCancer genes to the alteration  and
        % add the variable names
        if jj == 2
            curGeneClassAlterations(end+1,:) = {'All Cancer Genes', ...
                strjoin(cancerGenes.HugoSymbol) } ;
        end
        
        curGeneClassAlterations = array2table(curGeneClassAlterations,...
            'VariableNames',{'pathwayName','Genes'} );
        
        % get the alteration frequencies
        fprintf('\n Getting current gene class alterations \n')
        cur_Alterations_Results = find_MAPK_AlterationFreq( ...
            curGeneClassAlterations, mutations) ;
        
        % add the results to a struct
        results.([curGeneClass,'_Alterations']) = cur_Alterations_Results;
        
        % ********** Get the mean mutations of each gene ***************
        
        % each of the MAPK signalling RoleInCancers
        geneInClass = categorical( unique( cancerGenes.(jj) ) ) ;
        mean_Class_Alterations = zeros(height(mutations), ...
            length(geneInClass));
        
        for ii = 1:length(geneInClass)
            % get the mutations in each RoleInCancer using the alterations
            % of the genes for each of those RoleInCancers
            curClassCancerTable = mutations{:, ismember( ...
                mutations.Properties.VariableNames, ...
                cancerGenes.HugoSymbol(...
                cancerGenes.(jj) == geneInClass(ii)))};
            
            % convert to double if the data is a cell array
            if iscell(curClassCancerTable)
                curClassCancerTable = ...
                    double(~cellfun(@isempty, curClassCancerTable)) ;
            end
            
            % now find the samples that have alterations in mapk genes Get
            % for new analysis!!!
            mean_Class_Alterations(:,ii) = any(curClassCancerTable == 1,2);
            
        end
        
        % get the sum of all the mutations
        mean_Class_Alterations = sum(mean_Class_Alterations);
        
        % convert the mutation to a table
        mean_Class_Alterations = array2table(mean_Class_Alterations , ...
            'VariableNames',cellstr(geneInClass));
        
        % transpose the table and covert and the percentage of mutation to
        % the table and add the percetage of samples with mutations to the
        % table
        mean_Class_Alterations = rows2vars(mean_Class_Alterations);
        mean_Class_Alterations = addvars( mean_Class_Alterations,  ...
            mean_Class_Alterations.Var1/height(mutations)*100 );
        
        % add the variable names
        mean_Class_Alterations.Properties.VariableNames = ...
            {curGeneClass,'mutatedSamples','PercentAltered'} ;
        
        % add the results to a struct
        results.(['mean_',curGeneClass]) =  mean_Class_Alterations;
        
        
    end
    
    % ###################################################################
    
    fprintf('\n Getting Frequency of Alterations \n')
    % get the frequency of gene alterations of all MAPK genes so that I can
    % finally draw the RoleInCancer
    
    % ======= Each MAPK RoleInCancers Alterations Across Cancers ========
    if iscell( mutations.(4) )
        % the missing part is not work
        eachGeneMutations = sum(~cellfun(@isempty,mutations{:,3:end}))/ ...
            height(mutations) ;
    else
        eachGeneMutations = nansum(mutations{:,3:end})./ ...
            sum(~isnan(mutations{:,3:end})) ;
    end
    
    eachGeneMutations = array2table(...
        eachGeneMutations *100,'VariableNames',...
        mutations.Properties.VariableNames(3:end) );
    eachGeneMutations = rows2vars(eachGeneMutations );
    eachGeneMutations.Properties.VariableNames = ...
        {'Gene','PercentAltered'} ;
    eachGeneMutations = sortrows(eachGeneMutations,...
        'PercentAltered','descend');
    
    %  ====== Finally Get Mutations of Each Gene Across Cancers =========
    % get the mutations from the table by converting them to double
    AcrossCancerMutations = [ mutations(:,1) ,...
        array2table( double(~cellfun(@isempty,mutations{:,3:end}) == 1 ))];
    AcrossCancerMutations.Properties.VariableNames(2:end) = ...
        mutations.Properties.VariableNames(3:end) ;
    
    % convert to categorical so group stats can work properly
    AcrossCancerMutations.CancerStudy = categorical(...
        AcrossCancerMutations.CancerStudy);
    
    % get the groups starts
    AcrossCancerMutations = grpstats(AcrossCancerMutations,...
        'CancerStudy','sum');
    
    % divide each row by the total number of sample in each cancer study to
    % get the total percentage of mutations in for each gene
    for ii = 3:width(AcrossCancerMutations)
        % conver to the percentage of tumours with mutations
        AcrossCancerMutations.(ii) = ...
            (AcrossCancerMutations.(ii)./...
            AcrossCancerMutations.GroupCount)*100;
    end
    
    fprintf('\n Getting Overall Alterations for Each Gene \n')
    % finally change the variables names by remove sum from each genes
    AcrossCancerMutations.Properties.VariableNames(3:end) = ...
        extractAfter(...
        AcrossCancerMutations.Properties.VariableNames(3:end),'sum_');
    
    % set up the alteration of each gene across across
    eachGeneMutations.Properties.VariableNames(1) = "HugoSymbol" ;
    geneMutations = innerjoin(cancerGenes, eachGeneMutations);
    [~, these] = unique(geneMutations.HugoSymbol);
    geneMutations = geneMutations(these,:) ;
    geneMutations.Properties.VariableNames(end) = "meanAltered" ;
    
    % find the maximim alteartion of each gene across the various tumours
    eachGeneMax = rows2vars(AcrossCancerMutations(:, [1,3:end]), ...
        'VariableNamesSource','CancerStudy' );
    eachGeneMax.maxAltered = max(eachGeneMax{:,2:end} ,[],2) ;
    eachGeneMax.Properties.VariableNames(1) = "HugoSymbol" ;
    eachGeneMax = eachGeneMax(:, {'HugoSymbol','maxAltered'}) ;
    
    % now join this table to the one which shows mean gene alteration in
    % each gene across cancers
    geneMutations = innerjoin(geneMutations, eachGeneMax)  ;
    
    % sort the rows according to the most mutated
    geneMutations = sortrows(geneMutations,'meanAltered','descend') ;
    
    % add the results of mutations across all cancers to a struct
    results.('AcrossCancerMutations') = AcrossCancerMutations;
    
    % add the mutations of the mean and max gene mutations to the struct
    results.('geneMutations') = geneMutations;

    % get the number of samples with mutations in each cancer type
    numSampleMutated = addvars( mutations(:,1) ,...
       sum( double(~cellfun(@isempty,mutations{:,3:end}) == 1 ),2), ...
       'NewVariableNames',"numMutation" ) ;
    numSampleMutated.Mutated = double(numSampleMutated.numMutation > 0);

    % get the groups starts and percentage of tumours with mutations 
    numSampleMutated = grpstats(numSampleMutated,'CancerStudy','sum');
    numSampleMutated.percentMutated = numSampleMutated.sum_Mutated./ ...
        numSampleMutated.GroupCount*100 ;
    
    % add the results to the structred array 
    results.('mutatedSampleInEach') = numSampleMutated;

    % save the results
    save('mutation_results.mat','results')
end

clear mapkRoleInCancers ii jj locTFs cur_Alterations_Results ...
    curClassCancerTable curGeneClass curGeneClassAlterations ...
    eachGeneMax numClinSamples numMutSamples these TotalSample ...
    changeCodes geneInClass eachGeneMutations mean_Class_Alterations ...
    AcrossCancerMutations geneMutations ans

%% Get a supplemenatry figure of the genes not mutated 

try
    colorM = cbrewer('seq', 'OrRd', 50); % BuPu
    colorM(any(colorM < 0,2), :) = [] ;
catch
    colorM = parula;
end

% here are the mutations 
acrossMuts = results.AcrossCancerMutations ;
acrossMuts = acrossMuts(:,3:end) ;
acrossMuts = rows2vars(acrossMuts) ;
acrossMuts.Properties.VariableNames(1) = "HugoSymbol" ;

% get the genes mutated and not mutated for each genes
cgo = clustergram( acrossMuts{:,2:end},...
    'rowlabels', acrossMuts.HugoSymbol ,...
    'columnlabels', acrossMuts.Properties.VariableNames(2:end) ,...
    'colormap',colorM,'standardize','row','ColumnPDist','cosine', ...
    'Linkage','complete') ;

% add labels to the clustergram 
addXLabel(cgo,'Cancer Types','FontSize',12);
addYLabel(cgo,sprintf('%d Cancer Genes',height(acrossMuts)), ...
    'FontSize',12);

% Get figure handle
cgfig = findall(0,'type','figure', 'Tag', 'Clustergram');

% Get dendrogram axes
dendroAxRow = findall(cgfig,'Tag','DendroRowAxes');
dendroAxCol = findall(cgfig,'Tag','DendroColAxes');

% % Set their visibility to off
% set(dendroAxRow.Children, 'Visible', 'off')
% set(dendroAxCol.Children, 'Visible', 'off')

% % Alternatively, delete them:
% delete(dendroAxRow)
% delete(dendroAxCol)

% get a copy of the clustergram object and plot it for a sigle clustergram
cgoCopy = cgo ;

% plot the alterations rate of mutations and copy number changees in each
% tumour type 
alterRate = acrossMuts(:,2:end) ;

% change the arrangement in the alterationRate
[~, locX] = ismember(cgo.ColumnLabels, ...
    alterRate.Properties.VariableNames);
alterRate = alterRate(:,locX) ;

% throw in an assertion 
assert(all(strcmp(cgo.ColumnLabels',alterRate.Properties.VariableNames')))

% change the arrange of the data in alterRate 
alterRate = rows2vars(alterRate) ;
alterRate.Properties.VariableNames(1) = "CancerStudy" ;
alterRate.CancerStudy =  ...
    categorical(alterRate.CancerStudy,alterRate.CancerStudy) ;

% get the mutation frequencies
barData = alterRate(:,1) ;
barData.Zero = sum(alterRate{:,2:end} == 0,2) ;
barData.Less5 = sum(alterRate{:,2:end} < 5 & alterRate{:,2:end} > 0,2) ;
barData.Great5 = sum(alterRate{:,2:end} >= 5,2) ;

% ===== get the location of the data to produce the multiple plots ====

cgAxes = plot(cgoCopy);
set(cgAxes, 'Clim', [-1,1]) 

% plot the data at the specified location
axes('position',[0.2423 0.730 0.5760 0.25] );  % 0.0250

% here is the bargraph for the mean values
bh = bar(barData.CancerStudy,barData{:,2:end},'stacked');       
ylabel('# of genes')
legend({'0','<5','>=5'},'Location','best')

alphaV = [0.3 0.6 1] ;
for ii = 1:length(alphaV)
    bh(ii).FaceColor = [0.6350 0.0780 0.1840];
    bh(ii).FaceAlpha = alphaV(ii);
end

set(gca,'Box','off','XTick',[],'TickDir','out')

% save the bardata to excel 
alterRate = barData ;
writetable( alterRate,'Supplementary File 1.xlsx', ...
    'Sheet','mutation freq grouped')

% rearrange the data in across cancer mutations based on the clustering
% pattern on the tumours 
clustPattern = flipud(cgo.ColumnLabels');
[~,locThem] = ismember(clustPattern, ...
    results.AcrossCancerMutations.CancerStudy) ;
results.AcrossCancerMutations = results.AcrossCancerMutations(locThem,:);

% rearrage the categories
results.AcrossCancerMutations.CancerStudy = ...
    categorical(cellstr(results.AcrossCancerMutations.CancerStudy), ...
    cellstr(results.AcrossCancerMutations.CancerStudy)) ;

clear alphaV ii barDatalocX dendroAxRow dendroAxCol locThem ...
    clustPattern

%% Plot Bar Graph of Gene Mutations 

% here are the gene classes and the gene mutations
geneClass = cancerGenes.Properties.VariableNames(2:end) ;
geneMutations = results.geneMutations ;

% specify the class legend title 
titleCell = {'TSGs','Tumour Suppressor Genes';'Oncogenes','Oncogenes';...
    'Kinases','Kinases';'Phosphatases','Phosphatases';...
    'TFs','Transcription Factors';'Receptors','Receptors'} ;
theLetters = 'a':'j';

% get the colour pallete for the genes
palette = [0.737       0.235       0.161
        0.937       0.753       0
        0.125       0.522       0.306
        0.4940      0.1840      0.5560
        0.561       0.4667      0
        0.882       0.529       0.153
        0.435       0.600       0.678
        1.000       0.863       0.569
        0           0.451       0.761
        0.3010      0.7450      0.9330
        0.231       0.231       0.231];
    
% add the colors to a struct 
for ii = 1:size(titleCell,1)
    theColors.(titleCell{ii}) = palette(ii,:) ;
end
% also add the color for everything to the colors 
theColors.allGenes = [0 0.451 0.761] ;

% convert the data for categorical for easy indexing
for ii = 2:width(geneMutations)
    if iscell(geneMutations.(ii))
        geneMutations.(ii) = categorical(geneMutations.(ii)) ;
    end
end

% get the max genes that we need for plotting 
numOfGenes = 30 ;

figure()
% plot the bar graphs using a tiled layout
tiledlayout(4,2,'padding','compact');

for ii = 1:length(geneClass)
    
    % get the current variable name
    curVarname = geneClass{ii} ;
    
    % get the current gene classes and remove the other group
    curGeneClass = categories( geneMutations.(curVarname) );
    curGeneClass(ismember(curGeneClass,'Other')) = [] ;
    
    
    % get the data for oncogenes and plot the bar graph
    for jj = 1:length(curGeneClass)
        
        % get the cur class of genes and then get the data for that class
        curClass = curGeneClass{jj} ;
        curData = geneMutations( ...
            geneMutations.(curVarname) == curClass, :) ;
        
        % sort the data according to descendin order of mutation freqs and
        % get the top X mutated genes
        curData = sortrows(curData,'meanAltered','descend') ;
        try
            curData = curData(1:numOfGenes,:) ;
        catch
        end 
        
        % convert to categorical for plotting purposes 
        curData.HugoSymbol = categorical(curData.HugoSymbol,...
            curData.HugoSymbol) ;
        
        % Plot the data on a bargraph of on the tile 
        nexttile
        
        % here is the bargraph for the mean values
        bar(curData.HugoSymbol,curData.meanAltered,'FaceColor', ...
            theColors.(curClass),'EdgeColor',...
            theColors.(curClass));
        
        % add for the max values 
        hold on
        bar(curData.HugoSymbol,curData.maxAltered,...
            'FaceColor',theColors.(curClass),...
            'EdgeColor',theColors.(curClass),...
            'FaceAlpha',0.3,'EdgeAlpha',0.3);
        
        % edit the axis and and adjust the figure
        ylabel('% mutated')
        set(gca,'FontSize',12,'LineWidth',1,'Box','off',...
            'XTickLabelRotation',90)
        
        % add a legend and title to the figure
        legend({'Mean','Max'},'Box','off')

        % add a title to the figure 
        classTitle = titleCell{ ismember( ...
            titleCell(:,1),curClass), 2} ; 
        title(classTitle ,'FontSize',14,'FontWeight','bold')
        
        % add a letter to the figure and remove the letter from the array
        text(-0.1, 1 ,theLetters(1),'Units','normalized',...
            'FontWeight','bold','FontSize',24)
        theLetters(1) = [] ;
        
        % release the figure 
        hold off
    end 
end

% finally add another plot at the bottom of the figure: Call the nexttile
% function to create an axes object that spans ONE row by TWO columns.
% Then display a bar graph in the axes with a legend, and configure the
% axis tick values and labels. Call the title function to add a tile to the
% layout.
nexttile(7,[1 2]);

% get the current data for all the genes convert to categorical for
% plotting purposes
curData = geneMutations;

% sort the data according to descendin order of mutation freqs and
% get the top X mutated genes
curData = sortrows(curData,'meanAltered','descend') ;
curData = curData(1:70,:) ;
curData.HugoSymbol = categorical(curData.HugoSymbol,...
    curData.HugoSymbol) ;
        
% here is the bargraph for the mean values
bar(curData.HugoSymbol,curData.meanAltered,'FaceColor', ...
    theColors.allGenes,'EdgeColor',theColors.allGenes);

% add for the max values
hold on
bar(curData.HugoSymbol,curData.maxAltered,...
    'FaceColor',theColors.allGenes,'EdgeColor',theColors.allGenes,...
    'FaceAlpha',0.3,'EdgeAlpha',0.3);

% edit the axis and and adjust the figure
ylabel('% mutated')
set(gca,'FontSize',12,'LineWidth',1,'Box','off','XTickLabelRotation',90)

% add a legend and title to the figure
legend({'Mean','Max'},'Box','off')
title('All Genes','FontSize',14,'FontWeight','bold')

% add a letter to the figure and remove the letter from the array
text(-0.05, 1 ,theLetters(1),'Units','normalized',...
    'FontWeight','bold','FontSize',24)
theLetters(1) = [] ;

% release the figure
hold off

clear ii jj curData curGeneClass numOfGenes curClass ans classTitle ...
    curVarname class_legend fontSizes rectAndTextBox palette theLetters ...
    geneMutations

%% Plot a boxplot with a heatmap at the botton

% get the cancer mutations data and preallocate the bar data 
cancerMut = results.AcrossCancerMutations ;
barData = [];

% make the data according the mutations and study so they can be used to
% produce at bar graph
for ii = 1:height(cancerMut)
    % process the data in a loop
    if rem(ii,10) == 0
        fprintf('\nProcessing for study # %d of %d\n',ii,height(cancerMut))
    end
    
    % get the gene mutations for the current study
    curGeneMuts = rows2vars( cancerMut(ii,[1,3:end]) , ...
        'VariableNamesSource','CancerStudy') ;
    
    % change the variable names so i can use vert cat
    curGeneMuts.Properties.VariableNames = {'HugoSymbol','Freq'} ;
    
    % add the cancer study to the left of hte data
    curGeneMuts = addvars(curGeneMuts, ...
        repmat(cancerMut.CancerStudy(ii),...
        height(curGeneMuts),1), 'NewVariableNames','Study',...
        'Before', 1) ;
    
    % add these to the plot data
    barData = [barData; curGeneMuts ];
end

% here are the letter for the plots 
theLetters = 'a':'j';

figure()
% plot the bar graphs using a tiled layout
tiledlayout(8,4,'padding','compact');

% here is the next plot
nexttile([2,4]);

% plot a bar graph
vb = bar(cancerMut.CancerStudy, cancerMut.GroupCount,...
    'FaceColor','flat','FaceAlpha',0.9);

% change the color of the second bars graphs
rng(6)
barColours = rand(height(cancerMut),3) ;
for ii = 1:size(barColours)
    vb.CData(ii,:) = barColours(ii,:);
end

% edit the axis and and adjust the figure
ylabel('# of Samples')
set(gca,'LineWidth',1.5,'Box','off','XTickLabelRotation',90, ...
    'TickDir','out')

% ****************** VECTORISED IMPLEMENTATION *******************
% add number the top of the bar graph
text(1:length(cancerMut.GroupCount), cancerMut.GroupCount, ...
    num2str(cancerMut.GroupCount),'vert','bottom','horiz','center'); 
% ****************** VECTORISED IMPLEMENTATION *******************

box off

% add a legend and title to the figure
title('Samples in Studies','FontSize',14,'FontWeight','normal')

% add a letter to the figure and remove the letter from the array
text(-0.18/4, 1 ,theLetters(1),'Units','normalized',...
    'FontWeight','bold','FontSize',24)
theLetters(1) = [] ;

% here is the next plot
nexttile([3 4]);

% plot a colour box plot
colourBoxPlotInternal(barData.Freq, barData.Study, [], true)

% change some figure properties. 
set(gca,'XTickLabelRotation',90,'TickDir','out')
title('Mutations in Cancer Type','FontSize',14,'FontWeight','normal')
ylabel('% of samples with a mutant gene')

% add a letter to the figure and remove the letter from the array
text(-0.18/4, 1 ,theLetters(1),'Units','normalized',...
    'FontWeight','bold','FontSize',24)
theLetters(1) = [] ;

% *********************************************************************
% add a heatmap of the top mutated genes 15 mutated genes 

acrossCancer = results.AcrossCancerMutations ; 
acrossCancer = table(acrossCancer.Properties.VariableNames(3:end)', ...
    max(acrossCancer{:,3:end})' ,'VariableNames', ...
    {'HugoSymbol','Max'}) ;
acrossCancer = sortrows(acrossCancer,'Max','descend') ;

% get the top 20 genes 
theTopX = acrossCancer.HugoSymbol(1:25) ;

% get the alteration of the top genes 
topMuts = results.AcrossCancerMutations ;
topMuts = [topMuts(:,1), topMuts(:, ....
    ismember(topMuts.Properties.VariableNames,theTopX ) ) ] ;

% here is the next plot
nexttile([3 4]);

% add a letter to the figure and remove the letter from the array
text(-0.18/4, 1 ,theLetters(1),'Units','normalized',...
    'FontWeight','bold','FontSize',24)
theLetters(1) = [] ;

try
    colorM = cbrewer('seq','Blues',50); % BuPu
    colorM(any(colorM < 0,2), :) = [] ;
catch
    colorM = parula;
end

% get the data for the heatmap and sort the data according to the most
% frequently mutated genes
heatData = round(topMuts{:,2:end}',0) ;
[xVars,locThem] = sortrows(mean(heatData,2),'descend') ;
heatData = heatData(locThem,:) ;

% also sort the gene names
geneHeatNames = topMuts.Properties.VariableNames(2:end) ;
geneHeatNames = geneHeatNames(locThem) ;

% plot the last figure panel
heatmap(topMuts.CancerStudy,geneHeatNames, heatData ,'Colormap', colorM, ...
    'ColorbarVisible','off','GridVisible','off' ,'FontColor','k' ,...
    'FontSize',8);

% *********************************************************************
% heatData = sortrows([mean(heatData,2),heatData],'descend') ;
% heatData = heatData(:,2:end) ;

clear ii h vb barColours theTopX acrossCancer locThem geneHeatNames

%% Plot the heat map of the mutations across cancer types 

% here are the letters 
theLetters = 'a':'j';

% plot tiled layout
figure()
tileArray = [4 3 2 2] ;
tiledlayout(sum(tileArray),1,'padding','compact');

try
    % set up the colors for the four heatmap
    heatColours.Location = cbrewer('seq','Blues',50); % Blue
    heatColours.RoleInCancer = cbrewer('seq','Reds',100); % Oranges
    heatColours.Kinase_PPtase = cbrewer('seq','Greens',50); % Greens
    heatColours.TF = cbrewer('seq','Purples',50);
catch
    % set up the colors for the four heatmap
    heatColours.Location = parula; % Blue
    heatColours.RoleInCancer = parula; % Oranges
    heatColours.Kinase_PPtase = parula; % Greens
    heatColours.TF = parula;
end
heatColours.AllCancerGenes = parula ;

% plot the heatmaps in a loop
for ii = length(geneClass):-1:1
    
    % get the current data 
    curData = results.([geneClass{ii},'_Alterations']) ;
    
    % remove the other class from the data
    curData.Other = [] ;
   
    % here is the next plot
    nexttile([tileArray(ii) 1]);
    
    % get the current colour and remove the negative number that creep in 
    curColor = heatColours.(geneClass{ii}) ;
    curColor( any( curColor < 0,2) ,:) = [] ;
    
    if ii == 1
        % plot the heatmap
        h = heatmap(curData.CancerStudy, ...
            curData.Properties.VariableNames(2:end), ...
            round(curData{:,2:end}',0) ,...
            'Colormap', curColor,'ColorbarVisible','off');
    else
        h = heatmap(round(curData{:,2:end}',0) ,'Colormap', curColor,...
            'ColorbarVisible','off','ColorLimits',[50 100]);
        h.YDisplayLabels = curData.Properties.VariableNames(2:end);
        h.ColorLimits = [50 100];
    end
    
end

clear ii h hs curData 

%% Produce an UpSet Plot and a Pie Chart

% here we using the proteinClass and pathway from the data
geneClass = cancerGenes.Properties.VariableNames(2:end);
finalData = [] ;

% loop over the disease outcomes
% loop over the the pathways and proteinsclasses
for kk = 1:length(geneClass)
    
    fprintf('\n Running Upset plot analysis for %s \n', geneClass{kk})
    % covert the pathways to categorical for faster indexing
    cancerGenes.(geneClass{kk}) = ...
        categorical(cancerGenes.(geneClass{kk}));
    
    % get the genes altered for each pathway
    geneType = unique(cancerGenes.(geneClass{kk})) ;
    geneType(geneType == "Other") = [] ;
    
    % preallocated the appendTable for the samples with mutations in
    % each of the MAPK signalling pathways
    alterationSummary = zeros(height(mutations),length(geneType));
    
    for ii = 1:length(geneType)
        % get the mutations in each pathway using the alterations of
        % the genes for each of those pathways
        curPathwayTable = mutations{ :, ismember( ...
            mutations.Properties.VariableNames, ...
            cancerGenes.HugoSymbol( ...
            cancerGenes.(geneClass{kk}) == geneType(ii) ) ) };
        
        % convert to double 
        if iscell(curPathwayTable) 
            curPathwayTable = ~cellfun(@isempty,curPathwayTable) ;
            
        end
        
        % now find the samples that have alterations in mapk genes Get
        % for new analysis!!!
        alterationSummary(:,ii) = any(curPathwayTable == 1,2); 
    end
 
    % ***********************************************************
    % = Produce the upset plot as suggested by the REVIEWERS =
    % save a copy of the mutations across the various pathways into
    % a table that I will use for the UpSet plots only when the
    % outcomeVar is Pathway and not proteinClass
    alterationSummaryUpSet =  array2table(alterationSummary , ...
        'VariableNames', cellstr( geneType) ) ;
    
    % merge the upset datasets into one 
    finalData = [finalData,alterationSummaryUpSet ] ;
end

%% Here are the tumours with fewest mutations

% get the required studies
fewerMuts = results.AcrossCancerMutations ;
fewerMuts = fewerMuts( ...
    any(fewerMuts.CancerStudy == {'THYM','TGCT','THCA'},2), :) ;
fewerMuts = fewerMuts( :, [true, true, any(fewerMuts{:,3:end} > 5)] )

%% remove all the samples without any mutations

finalData(all(finalData{:,:} == 0,2),:) = [];

% get the rows of different combinations that will be used
% for comparison with the alterations data
uniqueRows = unique(finalData) ;

% process the upset plot data by geting the intersect for
% all points
inData = uniqueRows;

% now add the actuall number of samples with alterations in
% each location of the inData which has a 1
for ff = 1:height(uniqueRows)
    
    % the code below gives the number of rows in
    % alterationSummaryUpSet that are equal to the current
    % row uniqueRows
    totalSamples = all( finalData{:,:} == uniqueRows{ff,:}, 2);
    totalSamples = sum(totalSamples) ;
    
    % now add the number to the position in inData that are
    % = 1
    myPos = find( inData{ff,:} == 1);
    
    % now add the number to the table
    inData{ff,myPos} = totalSamples ;
    
end

% delete the rows that only have 1 (3 missing) valid samples
singleMutationData = inData( sum(inData{:,:} ~= 0,2) == 1 , :) ;
inData( sum(inData{:,:} ~= 0,2) == 1 , :)  = [] ;

% sort the rows of the table
valuesPerRow = max(inData{:,:},[] ,2) ;
[~ , locOrder ] = sortrows(valuesPerRow ,'descend') ;
inData = inData(locOrder, :)  ;

% sort the one mutation data table 
valuesPerRow = max(singleMutationData{:,:},[] ,2) ;
[~ , locOrder ] = sortrows(valuesPerRow ,'descend') ;
singleMutationData = singleMutationData(locOrder, :)  ;

% transpose the table to make it usable with upSetPlot code
inData = rows2vars(inData);
singleMutationData = rows2vars(singleMutationData);

% ================= produce the upset plot ==============
figure()
upSetPlot(inData,theColors)

% produce another upSetPlot
figure()
upSetPlot(singleMutationData,theColors)

clear ii inData valuesPerRow locOrder totalSamples ff finalData ...
    uniqueRows singleMutationData alterationSummaryUpset ans fewerMuts ...
    kk myPos curPathwayTable curColor barData alterationSummary

%% Add the average transcription factor alterations bar graph

% preallocate the average mutations
aveMuts = [] ;

% put the data together in the table 
for ii = 1:length(geneClass)
    
    % get the current data and changet the first variable name to class
    curData = results.(['mean_',geneClass{ii}]) ;
    curData.Properties.VariableNames(1) = "geneClass" ;
    
    % remove the other class from the data 
    curData(ismember(curData.geneClass,'Other'), :) = [] ;
    
    % merge the two table 
    aveMuts = vertcat(aveMuts,curData) ;
    
end

% sort the rows of the table 
aveMuts = sortrows(aveMuts,'PercentAltered','descend');

% convert the geneClass to categorical
aveMuts.geneClass = categorical(aveMuts.geneClass,aveMuts.geneClass);

figure()
% plot a bar graph
vb = bar(aveMuts.geneClass,aveMuts.PercentAltered,...
    'FaceColor','flat','FaceAlpha',0.9);

% change the color of the second bars graphs
rng(6)
geneTypes = categories(aveMuts.geneClass);
for ii = 1:size(geneTypes)
    vb.CData(ii,:) = theColors.(geneTypes{ii}) ;
end

% ******************* VECTORISED IMPLEMENTATION *************************
text(1:length(aveMuts.PercentAltered), round(aveMuts.PercentAltered,1), ...
    num2str(round(aveMuts.PercentAltered,1)), ...
    'vert','bottom','horiz','center')
% ******************* VECTORISED IMPLEMENTATION *************************

% edit the axis and and adjust the figure
ylabel('% of Samples')
set(gca,'LineWidth',1,'FontSize',12,'Box','off')

% add a legend and title to the figure
title('Gene Mutations','FontSize',14,'FontWeight','bold')

%% Save the data use for plotting 

fprintf('\n Saving the supplementary files results \n')

% save some supplementary files
writetable( cancerGenes ,'Supplementary File 1.xlsx', ...
    'Sheet','Cancer Genes') ;
writetable( results.AcrossCancerMutations ,'Supplementary File 1.xlsx',...
    'Sheet', 'Within Cancer Mutations');
writetable( results.RoleInCancer_Alterations , ...
    'Supplementary File 1.xlsx','Sheet','OGs and TSGs');
writetable(results.Kinase_PPtase_Alterations,...
    'Supplementary File 1.xlsx','Sheet', 'Kinases and Phosphatases');
writetable(results.TF_Alterations, 'Supplementary File 1.xlsx',...
    'Sheet', 'Transcription Factors');
writetable(results.geneMutations,'Supplementary File 1.xlsx',...
    'Sheet','Each Gene Mutation');

%% Produce a an excel file of cancer genes venn diagram 

% here are the genes mutations 
geneMutations = results.geneMutations;

% process the data in a loop 
letters ='A':'F' ;

for ii = 2:5
    % get the data for the current row in cancer
    curGenes = geneMutations( ...
        ~ismember(geneMutations.(ii), 'Other'),{'HugoSymbol'}) ;
    curGenes.Properties.VariableNames = ...
        geneMutations.Properties.VariableNames(ii) ;
    
    % save to excel 
    writetable(curGenes,'Venn_CCG.xlsx','Range', ...
        sprintf('%s1',letters(ii-1)) )
    
end

clear ii curGenes letters

%% Cancer Gene with no mutations

% get the sames with no mutations
geneMutations = results.geneMutations;
geneMutations = addvars(geneMutations, ~geneMutations.maxAltered == 0, ...
    'After','HugoSymbol','NewVariableNames','MutationStatus') ;

% get some statitics 
genesMutated = sum(geneMutations.MutationStatus) 
genesNotMutated = sum(~geneMutations.MutationStatus) 
percentMutatedGenes = genesMutated/height(geneMutations)

% check these values against the cosmic database
cosmic = readtable('Cancer_Gene_Census_Hallmarks_Of_Cancer.tsv',...
    'FileType','text') ;
cosmic( ~cellfun(@isempty, cosmic.CELL_LINE), :) =  [] ;
cosmic.CELL_LINE = [];
cosmic.Properties.VariableNames(1) = "HugoSymbol" ;

% return on the gene present in the cosmic data that are cancer genes
cosmic( ~ismember(cosmic.HugoSymbol,geneMutations.HugoSymbol), :) = [] ;

% join with the gene mutations data 
geneMutations = outerjoin(geneMutations,cosmic,'MergeKey',true);
geneMutations.HALLMARK = categorical(geneMutations.HALLMARK);

% get the most common hallmarks
hallmarks = table( categories(geneMutations.HALLMARK), ...
    countcats((geneMutations.HALLMARK)),'VariableNames', ...
    {'Hallmark','Count'}) ;
hallmarks = sortrows(hallmarks,'Count','descend'); 

% here is the mutated table
mutatedOnlyTable = geneMutations(geneMutations.MutationStatus == 1, :);

% save to excel and use for table 
writetable(geneMutations,'Supplementary File 2.xlsx') ;
writetable(geneMutations,'Tableau Mutations and Hallmarks.xlsx');
writetable(mutatedOnlyTable,'Mutated Only Genes.xlsx') ;

% create a table of of each genes 

clear mutatedOnlyTable

%% Have a t-SNE plot of mutation

% get the accross cancer mutation and remove the point with less than 1%
% mutations 
mutFreqs = ~cellfun(@isempty, mutations{:,3:end}) ;
mutFreqs = mutFreqs(:, sum(mutFreqs,1)/height(mutations) > 0.02) ;
mutFreqs = double(mutFreqs);

rng(6)
groupColours = rand(height(categories(mutations.CancerStudy)),3) ;

% run a tnse
rng default % for reproducibility
yValues = tsne(mutFreqs,'Distance','euclidean')  ;


% plot the data 
figure()
gscatter(yValues(:,1),yValues(:,2), mutations.CancerStudy,...
    groupColours,'..',40)
set(gca,'LineWidth',1,'Box','off','FontWeight','bold')
xlabel('tSNE-1') ;
ylabel('tSNE-2') ;
title('Cancer Type Clustering','FontSize',14','FontWeight','bold')
    
%% 

% Most common amino acid mutation

% from which amino acid to what?

% what type of mutations

%% Co-occurance and Mutually Exclusive - Pancancer

% a probablity of 0 is towards cooccurance and towards 1 is mutually
% exclusive

% process the mutations data into 1 and 0 
mutTable = mutations(:,[1,3:end]);
for ii = 2:width(mutTable)
    mutTable.(ii) = double(~cellfun(@isempty,mutTable.(ii) )) ;
end

%% get mutation in the current cancer

% if the data has not been processed
if ~exist('acrossCancerMutOccurence.mat','file')
    fprintf('\nGetting the mutation co-occurances\n')
    
    % get a smaller table to work with
    smallMut = mutTable ;
    
    % keep the gene that mutated in more than 5% of the samples for the
    % current cancer types
    smallMut = smallMut(:, ...
        [true, sum(smallMut{:,2:end})/height(smallMut) > 0.01]);
    
    assert( all( sum(smallMut{:,2:end}) > 0.01) )
    
    % get the occurance of mutations in cancer
    [~,acrossCancerMutOccurence] = my_mutCorrelation(smallMut) ;
    
    % clean up the data
    acrossCancerMutOccurence = removevars( ...
        acrossCancerMutOccurence,{'dotx','doty','scatterSize'});
    acrossCancerMutOccurence.tumortype = [];
    acrossCancerMutOccurence = sortrows( ...
        acrossCancerMutOccurence,'pval','ascend') ;
    
    % remove the rows with no mutations
    acrossCancerMutOccurence( ...
        cellfun(@isempty, acrossCancerMutOccurence.genex), :) = [] ;
    
    % convert this to a categorical array
    acrossCancerMutOccurence.corType = ...
        categorical(acrossCancerMutOccurence.corType) ;
    summary(acrossCancerMutOccurence.corType)
    
    % save the results
    save('acrossCancerMutOccurence.mat','acrossCancerMutOccurence')
else
    % load hte processed data 
    load('acrossCancerMutOccurence.mat')
end

% plot a pie chart of the mutation pattern landscape
pieLabels = grpstats( ...
    acrossCancerMutOccurence(:, {'corType','odds'}), 'corType') ;

figure()
pie(pieLabels.GroupCount ,[0 1 1], cellstr(pieLabels.corType) )

% get the mutual exclusivity mutatioons
acrossCancerExclus = acrossCancerMutOccurence( ...
    ismember(acrossCancerMutOccurence.corType,'mutual exclusivity'), :);

% freqMutated = results.geneMutations.HugoSymbol(1:10)' ;

across_mapk_akt = acrossCancerMutOccurence( ...
    all( ismember( [acrossCancerMutOccurence.genex, ...
    acrossCancerMutOccurence.geney] , ...
    {'PIK3CA','TP53','KRAS','BRAF','IDH1','EGFR'} ),2 ), :);

clear freqMutated

%% Co-occurance and Mutually Exclusive - for Each Cancer Type

if ~exist('cancerMutOccurence.mat','file')
    
    fprintf('\nGetting within cancer the mutation co-occurances\n')
    
    % preallocate all the cancer types
    mutOccurence = [] ;
    
    % get the mutual and cooccurance
    myStudies = unique(cellstr(mutTable.CancerStudy));
    
    % run in a loop
    parfor ii = 1:length(myStudies)
        
        fprintf('\nRunning analysis for the study %s # %d\n', ...
            myStudies{ii}, ii)
        
        % get mutation in the current cancer
        smallMut = mutTable( mutTable.CancerStudy == myStudies{ii}, :) ;
        
        % keep the gene that mutated in more than 5% of the samples for the
        % current cancer types
        smallMut = smallMut(:, ...
            [true, sum(smallMut{:,2:end})/height(smallMut) > 0.05]);
        
        assert( all( sum(smallMut{:,2:end}) > 0.05))
        
%         % return the top 10 mutations genes - get the genes mutated
%         % in atleast % 5% of the samples 
%         locTopMuts = sum(smallMut{:,2:end}) ;
%         
%         % check that I have many data point
%         if length(unique(locTopMuts)) < 30
%             % get only the genes that are mutated more than 1 times(2)
%             maxVar = length(unique(locTopMuts))-1 ;
%         else
%             maxVar = 30 ;
%         end
%         
%         theTop15 = find( ismember(locTopMuts, maxk(locTopMuts,maxVar)));
%         
%         % here are the mutation. Sometime they are more than 200 data
%         % point % reduct them 
%         smallMut = smallMut(:,[1,theTop15+1]) ;
        
        [~,curOccurance] = my_mutCorrelation(smallMut) ;
        
        % add to the growing results
        mutOccurence = [ mutOccurence; curOccurance ];
        
    end
    % save the results
    save('cancerMutOccurence.mat','mutOccurence')
else
    % load hte processed data
    load('cancerMutOccurence.mat')
end

% put everything together
mutOccurence = removevars(mutOccurence,{'dotx','doty','scatterSize'});
mutOccurence = sortrows(mutOccurence,'pval','ascend') ;

% clean up the variables
mutOccurence(cellfun(@isempty, mutOccurence.genex), :) = [] ;
mutOccurence.corType = categorical(mutOccurence.corType);

% plot a pie chart of the mutation pattern landscape
pieLabels = grpstats(mutOccurence(:, {'corType','odds'}), 'corType') ;

figure()
pie(pieLabels.GroupCount ,[0 1 1], cellstr(pieLabels.corType) )

% plot a graph that show the number of co-occuring and mutually exclusive
% mutation among cancer genes across each cancer type and for each pair of
% cancer genes - oncogene to oncogene
mutOccurence.tumortype = categorical(mutOccurence.tumortype);
eachCancer = grpstats( mutOccurence(:,{'tumortype','corType','odds'}), ...
    {'tumortype','corType'}, 'numel','DataVar','odds') ;

% change the first vairable name 
eachCancer.Properties.VariableNames(1) = "CancerStudy" ;

%save to excel 
writetable(mutOccurence,'withinCancerCooccurrence.xlsx','Sheet','all')
writetable(eachCancer,'withinCancerCooccurrence.xlsx','Sheet','summary')

% all the exclusive mutations in cancer 
withinCancerExclus = mutOccurence( ismember( ...
    mutOccurence.corType,'mutual exclusivity'), :);

% pi3k and p53 mutaions in cancer 
pi3k_p53 = mutOccurence( all( ismember(...
    [mutOccurence.genex, mutOccurence.geney] , ...
    {'PIK3CA','TP53','KRAS','PTEN'}),2 ), :) ;
pi3k_p53( pi3k_p53.corType == 'none', :)  = [] ;
pi3k_p53.GeneNames = strcat( pi3k_p53.genex,'-', pi3k_p53.geney);
pi3k_p53 = sortrows(pi3k_p53,'GeneNames','descend');

%% Plot a bargraph of co-occurance and exclusive mutations

% get the dat for ploting
corrData = eachCancer ;

corrData = outerjoin(corrData, ...
    results.AcrossCancerMutations( ...
    :,{'CancerStudy','GroupCount'}), 'Key','CancerStudy', ...
    'MergeKey',true) ;

corrData.numel_odds = [] ;
corrData.Properties.VariableNames(3:end) = {'Count','Samples'} ;

% get each type of mutation in signle files 
occurrenceD = corrData( corrData.corType == "co-occurrence",:) ;
occurrenceD.Properties.VariableNames(2) = "co-occurrence" ;
exclusiveD = corrData( corrData.corType == "mutual exclusivity",:) ;
exclusiveD.Properties.VariableNames(2) = "mutual exclusivity" ;
noneD = corrData( corrData.corType == "none", :) ;
noneD.Properties.VariableNames(2) = "none" ;
    
% make one table 
corrData = outerjoin( outerjoin(occurrenceD,exclusiveD, ...
    'Key','CancerStudy','MergeKey',true), ... 
    noneD, 'Key','CancerStudy','MergeKey',true) ;

writetable(corrData,'tableauMutationCorrelation.xlsx')

clear noneD exclusiveD occurrenceD

%% plot clustergram of co-occuring mutation and exclusive mutation 

% us tableau to plot these data 

% here the y-axis labels
theYlabel = {'co-occurrence','# of samples'} ; %,'mutation count'};

% mutation count = clinicalData(:,{'CancerStudy','MUTATION_COUNT'})

% plot tiled layout
figure()
tiledlayout(1,length(theYlabel),'padding','compact');

% get only the data of tumours of mutual exclusivity mutation
for ii = 1:length(theYlabel)
    
    % get the current data
    if ii == 1
        
        % get the qualifying cancer types 
        theMutEx = eachCancer ;
        toKeep = table( categories(theMutEx.CancerStudy), ...
            countcats(theMutEx.CancerStudy)) ;
        toKeep(toKeep.Var2 < 3, :) = [] ;

        % for the co-occurance
        theMutEx = eachCancer( ismember( ...
            eachCancer.CancerStudy, toKeep.Var1), :) ;
        
        % get the correlation data
        xVar = theMutEx.GroupCount( ...
            theMutEx.corType == "mutual exclusivity") ;
        yVar = theMutEx.GroupCount(theMutEx.corType == "co-occurrence") ;
    
    elseif ii == 2
        % for the number of samples
        theMutEx = eachCancer(eachCancer.corType =="mutual exclusivity",:);
        theMutEx = innerjoin(theMutEx, ...
            results.AcrossCancerMutations( ...
            :,{'CancerStudy','GroupCount'}), 'Key','CancerStudy') ;
        
        % get the x and y values
        xVar = theMutEx.GroupCount_theMutEx ;
        yVar = theMutEx.GroupCount_right ;
        
    else
        % for the mutation frequency data
        
    end
    
    % here is the next plot
    nexttile;
    
    % here the scatter plot
    scatter(xVar,yVar,80,'filled','MarkerFaceColor',[0.2010 0.2450 0.8330] )
    h2 = lsline ;
    h2.LineWidth = 2;
    h2.Color = [0.2010 0.8330 0.2450];
    
    hold on
    set(gca,'FontSize',12,'LineWidth',1,'FontSize',12 ,'Box','off',...
        'FontWeight','bold')
    
    % calculate correlation between the two point
    X = [ones(length(xVar),1) xVar] ;
    b1 = X\yVar ; yCalc1 = X*b1 ;
    r2 = 1 - sum((yVar - yCalc1).^2)/sum((yVar - mean(yVar)).^2) ;
    
    % legend({'points','Linear'},'Location','Best')
    text(0.4, 0.9, sprintf('R = %0.2f', r2),'FontSize',14, ...
        'Units','normalized')
    
    % add figure labels
    xlabel('mutual exclusivity')
    ylabel(theYlabel{ii})
    % title('Gene Pair Mutations','FontSize',14)
    
end

clear pieLabels ii  locTopMuts theTop15 h2 X b1 r2 xVar yVar

%% Plot of Results of Mutations

pi3k_p53.tumortype  = cellstr(pi3k_p53.tumortype );

% first create a network 
myGraph = digraph(pi3k_p53.tumortype , pi3k_p53.GeneNames);
myGraph.Edges.Interaction = pi3k_p53.corType ;

% plot the graph
figure()
try
    hGraph = plot(myGraph,'layout','layered','usegravity',true,...
        'MarkerSize',40,'ArrowSize', 10,'EdgeAlpha',0.80 ,...
        'LineWidth', 0.5000,'NodeFontSize',12);
catch
    hGraph = plot(myGraph,'layout','layered',...
        'MarkerSize',40,'ArrowSize', 10,'EdgeAlpha',0.80 ,...
        'LineWidth', 0.5000,'NodeFontSize',12) ;
end

set(gca,'FontSize',12,'FontWeight','bold','visible', 'off')
title('Top Cancer Genes Network','FontSize',18)

hold on

% get the nodes that have edge for interactions from biogrid
allInters =  unique(myGraph.Edges.Interaction) ;

for ii = 1:length(allInters)
    
    % get the current interaction 
    cur_inter = allInters(ii) ;
    
    % get the location of the interaction 
    locsG = ismember(myGraph.Edges.Interaction,cur_inter);
    
    % find the end
    [sOut,tOut] = findedge(myGraph);
    allEdges = [sOut,tOut];
    
    
    % check = mtorGraph.Edges(locsG,:) ;
    subGraph = allEdges(locsG,:) ;
    subGraph = reshape( subGraph',1,[]) ;
    
    % if the interaction is just protein-protein
    if cur_inter == "mutual exclusivity"
        highlight(hGraph,subGraph,'EdgeColor',[0.73 0.03 0.73], ...
            'LineWidth',1.5 ,'LineStyle','-','NodeFontWeight','bold')
    else
        highlight(hGraph,subGraph,'LineWidth',1.5 ,'LineStyle','-',...
            'NodeFontWeight','bold')
    end
    
end

% get the nodes of cancers and highlight them
myNodes = myGraph.Nodes.Name( ~contains(myGraph.Nodes.Name,'-') ) ;
highlight(hGraph,myNodes,'NodeColor',[0.73 0.3 0.3])

% add a legend ot the plot
% the first line
X = [0.1 0.15];
Y = [0.8   0.8];
annotation('arrow',X,Y,'Color',[0.73 0.03 0.73],'LineWidth',1.5);
text(0.04,0.85,'co-occurrence','Units','normalized','FontSize',12)

% second line
Y = [0.76   0.76];
annotation('arrow',X,Y,'Color',[0 0.4470 0.7410],'LineWidth',1.5);
text(0.04,0.80,'mutual exclusivity','Units','normalized','FontSize',12)

% point for the genes 
annotation('ellipse',[0.12, 0.70, 0.025 0.035],'FaceColor',[0.73 0.3 0.3])
text(0.04,0.75,'cancer type','Units','normalized','FontSize',12)

annotation('ellipse',[0.12, 0.65, 0.025 0.035],'FaceColor',[0 0.447 0.741])
text(0.04,0.69,'gene pair','Units','normalized','FontSize',12)

% finally put the text in the rectangle 
annotation('rectangle',[0.09, 0.64, 0.20 0.19],'Color','black')

hold off

%% How is the survival of patients affected by co-occuring mutations 

% load the clinical data from the MAPK data 
load('metabolicData.mat','clinicalData')

% return only the TCGA studies given in the pi3k_p53 data for the top
% mutated genes 
clinicalData.CancerStudy = categorical( extractBefore(  ...
    clinicalData.CancerStudy,'_') );
clinicalData = clinicalData( ismember( clinicalData.CancerStudy , ...
    pi3k_p53.tumortype), :) ;
clinicalData.SampleIds = extractBefore( clinicalData.SampleIds,13) ;

% Produce table for the disease free survival and overall survival across
% here are the studies
survStudies = pi3k_p53 ;
survStudies.Properties.VariableNames(1) = "CancerStudy" ;
survStudies.CancerStudy = categorical(survStudies.CancerStudy);

% preallocate the tables 
osMultiTable = [] ; 
dfsMuliTable = []  ;

% here are the ordinary table 
osTable = cell2table( cell(height(survStudies),4), ...
    'Variablenames',{'GeneNames','cancerStudy','pValue','adjPvalue'} ) ;
dfsTable = osTable ;

% here are the disease outcome
clinicalOutcomes = ["overallSurvival","diseaseFreeSurvival"];

% loop over the clinical outcomes
for jj = 1:length(clinicalOutcomes)
    
    % loop over the cancer studies
    for ii = 1:height(survStudies)
        
        % count the preallocation for the current row
        curRow = ii ;
   
        % get the current study and gene alteration for that cancer
        curCancer = string(survStudies.CancerStudy(ii)) ;
        curMuts = mutations(mutations.CancerStudy == curCancer,:) ;
        curClinical = clinicalData( ...
            clinicalData.CancerStudy == curCancer,:);
        
        % get the common samples in mutations and clinical data and arrange
        % the clinical data according to the mutations data
        [~, themA, themB ] = intersect(curClinical.SampleIds, ...
            curMuts.SampleIds ,'stable') ;
        curMuts = curMuts(themB,:) ;
        curClinical = curClinical(themA,:);
        
        % throw in an assession
        assert(all(strcmp(curClinical.SampleIds,curMuts.SampleIds)))
        
        fprintf('\nFinding clinical outcomes in %s Cancer and Genes %s\n',...
            curCancer , survStudies.GeneNames{ii} )
        
        % get only the required genes from the mutations data
        curMuts = curMuts(:, ismember( curMuts.Properties.VariableNames,...
            [survStudies.genex(ii), survStudies.geney(ii)] ));
        
        % get the altered samples
        curMutProfile = cell(height(curMuts),1) ;
        
        % covert the mutations to a double
        mutatedSamples = ~cellfun(@isempty,curMuts{:,:}) ;
        
        % annotate the mutations in samples
        curMutProfile( mutatedSamples(:,1)) =  ...
            strcat( curMuts.Properties.VariableNames(1), ' Mutated') ;
        curMutProfile( mutatedSamples(:,2)) =  ...
            strcat( curMuts.Properties.VariableNames(2), ' Mutated') ;
        curMutProfile( all(mutatedSamples,2)) = {'Both Mutated'} ;
        curMutProfile( ~any(mutatedSamples,2) ) = {'Not Mutated'} ;
        
        % ========================= Surival Analysis =====================
        % survival analysis for abacavir metabolism vs non abacavir
        % metabolism
        
        % Get the Overall Survival Data and the Disease Free Survival Data
        % and delete the missing low from the data
        if strcmp(clinicalOutcomes(jj),'overallSurvival')
            OsData = [curClinical.OS_MONTHS,curClinical.OS_STATUS , ...
                curMutProfile] ;
            OsData(any(cellfun(@isempty,OsData),2),:) = [] ;
            
        else
            % create for the data for disease free survival: first make the
            % disease free data compatible with the matSurv function
            OsData = [curClinical.DFS_MONTHS, ...
                strrep(regexprep(curClinical.DFS_STATUS,'/(\w+)',''),...
                'Recurred', 'Relapsed') ,curMutProfile ] ;
            OsData(any(cellfun(@isempty,OsData),2),:) = [] ;
        end
        
        % check if the cancer study had overall survival data
        if all( cellfun(@isempty, OsData(:,1)) )
            break ;
        end
        
        % Anonotate the groups to either pathway mutated or pathway
        % unmutated and perferom K-M Survival Analysis
        groups = OsData(:,3)  ;
        
        % ============= PERFORM OVERALL SURVIVAL ANALYSIS =================
        [logRankP, ~, OsStats] = MatSurv( str2double(OsData(:,1)), ...
            lower(OsData(:,2)) , groups, 'NoRiskTable',true ,...
            'NoPlot',false,'PairWiseP',true ,'setLegendWithNumbers',true );
        
        % put the results in a table
        if strcmp(clinicalOutcomes(jj),'overallSurvival')
            % add the data to a table
            osTable.GeneNames(curRow) = survStudies.GeneNames(ii);
            osTable.cancerStudy(curRow) = cellstr(curCancer) ;
            osTable.pValue{curRow} = logRankP ;
        else
            % add the data to a table
            dfsTable.GeneNames(curRow) = survStudies.GeneNames(ii);
            dfsTable.cancerStudy(curRow) = cellstr(curCancer) ;
            dfsTable.pValue{curRow} = logRankP ;
        end
       
        % get the os data for the current cancer study
        osPairwise = struct2table( OsStats.ParwiseStats ) ;
        osPairwise.GroupNames = OsStats.ParwiseName ;
        osPairwise = sortrows(osPairwise,'p_MC','ascend');
        osPairwise = addvars( osPairwise, ...
            repmat(categorical(curCancer),height(osPairwise),1),  ...
            repmat( cellstr( survStudies.GeneNames{ii}), ...
            height(osPairwise),1),  ...
            'NewVariableNames',{'CancerStudy','GeneNames'},'Before',1) ;
        
        % annotate the plot
        set(gca,'LineWidth',1.5,'FontSize',12,'FontWeight','bold',...
            'TickDir','out')
        
        if strcmp(clinicalOutcomes(jj),'overallSurvival')
            % annotate the plots
            figName = ['OS: ', char(curCancer) ,': ', ...
                survStudies.GeneNames{ii},' (', ...
                char(survStudies.corType(ii)),')' ] ;
            title(figName, 'Fontsize',14,'FontWeight','bold')
            
            % add the data to a table
            osMultiTable = [osMultiTable ; osPairwise ] ;
            
            % save the figures
            saveas(gcf,[replace(figName,':','_'),'.fig'],'fig')
            saveas(gcf,[replace(figName,':','_'),'.png'],'png')
        else
            % annotate the plots
            figName = ['DFS: ', char(curCancer) ,': ', ...
                survStudies.GeneNames{ii},' (', ...
                char(survStudies.corType(ii)),')' ] ;
            title(figName, 'Fontsize',14,'FontWeight','bold')
            
            % add the data to a table
            dfsMuliTable = [dfsMuliTable ; osPairwise ] ;
            
            % save the figures
            saveas(gcf,[replace(figName,':','_'),'.fig'],'fig')
            saveas(gcf,[replace(figName,':','_'),'.png'],'png')
        end
    end
end

% add the adjusted p values to the table 
osMultiTable.adjPvalue = mafdr(osMultiTable.p_MC ,'BHFDR',true);
dfsMuliTable.adjPvalue = mafdr(dfsMuliTable.p_MC , 'BHFDR',true);

% remove the instances where the sample sizes in atleast one group is less
% than 10 and sort the rows of the tables 
osMultiTable = sortrows(osMultiTable ,'adjPvalue','ascend') ;
dfsMuliTable = sortrows(dfsMuliTable ,'adjPvalue','ascend') ;

% save the data to a table 
writetable(osMultiTable,'Clinical Outcomes Per Cancer.xlsx','Sheet',...
    'MultiCompare OS')
writetable(dfsMuliTable,'Clinical Outcomes Per Cancer.xlsx','Sheet',...
    'MultiCompare DFS')

% also process the non multicompare results 
% remove the rows without p values add the adjusted pvalues 
osTable( cellfun(@isempty,osTable.pValue ),: ) = [] ;
dfsTable( cellfun(@isempty, dfsTable.pValue), :) = [] ;

osTable.adjPvalue = mafdr(cell2mat(osTable.pValue ) ,'BHFDR',true);
dfsTable.adjPvalue = mafdr(cell2mat(dfsTable.pValue) , 'BHFDR',true);

% remove the instances where the sample sizes in atleast one group is less
% than 10 and sort the rows of the tables 
osTable = sortrows(osTable ,'adjPvalue','ascend') ;
dfsTable = sortrows(dfsTable ,'adjPvalue','ascend') ;

% change the values to double 
for ii = 3:width(osTable)-1 % minus because we dont include the adjPvalue
    osTable.(ii) = cell2mat( osTable.(ii) ) ;
    dfsTable.(ii) = cell2mat( dfsTable.(ii) ) ;
end

% save the data to a table 
writetable(osTable,'Clinical Outcomes Per Cancer.xlsx','Sheet',...
    'Overall Survival')
writetable(dfsTable,'Clinical Outcomes Per Cancer.xlsx','Sheet',...
    'Disease Free Survival')

fprintf('\n Done with survival analysis \n\n')

clear tableH logRankP DFSstats groups dfsData OsData ...
    curPathawayAltersMutants curStudyClinical curPathwayGenes ...
    curPathway curGeneAlters curMuts curCancer curCNA  curGeneAlters ...
    locCurPathway curRow clinicalOutcomes

%% Pancancer survival analysis 

% get the mutual exclusivity mutatioons
panCancerImpo = unique([acrossCancerExclus; across_mapk_akt ], 'rows');
panCancerImpo.GeneNames = ...
    strcat(panCancerImpo.genex,'-', panCancerImpo.geney);

% load the clinical data from the MAPK data 
load('metabolicData.mat','clinicalData')

% return only the TCGA studies given in the pi3k_p53 data for the top
% mutated genes 
clinicalData = clinicalData( contains( clinicalData.CancerStudy , ...
    'TCGA','IgnoreCase',true), :) ;
clinicalData.CancerStudy = categorical( extractBefore(  ...
    clinicalData.CancerStudy,'_') );
clinicalData.SampleIds = extractBefore( clinicalData.SampleIds,13) ;

%% Produce table for the disease free survival and overall survival across

% check if this analysis has been performed 
if ~exist('Clinical Outcomes Per Cancer.xlsx','file')
    
    % here are the studies
    survStudies = panCancerImpo ;
    
    % preallocate the tables
    osPanMultiTable = [] ;
    dfsPanMuliTable = []  ;
    
    % here are the ordinary table
    osPanTable = table( 'Size',[height(survStudies),8], ...
        'Variablenames',{'GeneNames','Pattern','BothMutated',...
        'Gene1_Mutated','Gene2_Mutated','NoneMutated','pValue',...
        'adjPvalue'},...
        'VariableTypes',{'char','categorical','double','double',...
        'double','double','double','double'}) ;
    dfsPanTable = osPanTable ;
    
    % here are the disease outcome
    clinicalOutcomes = ["overallSurvival","diseaseFreeSurvival"];
    
    % get the current study and gene alteration for that cancer
    curMuts = mutations ;
    curClinical = clinicalData;
    
    % get the common samples in mutations and clinical data and arrange
    % the clinical data according to the mutations data
    [~, themA, themB ] = intersect(curClinical.SampleIds, ...
        curMuts.SampleIds ,'stable') ;
    curMuts = curMuts(themB,:) ;
    curClinical = curClinical(themA,:);
    
    % throw in an assession
    assert(all(strcmp(curClinical.SampleIds,curMuts.SampleIds)))
    
    % loop over the clinical outcomes
    for jj = 1:length(clinicalOutcomes)
        
        % loop over the cancer studies
        for ii = 1:height(survStudies)
            
            fprintf('\nFinding clinical outcomes in Cancer and Genes %s\n',...
                survStudies.GeneNames{ii} )
            
            % get only the required genes from the mutations data
            loopMuts = curMuts(:, ismember( ...
                curMuts.Properties.VariableNames,...
                [survStudies.genex(ii), survStudies.geney(ii)] )) ;
            
            % get the altered samples
            curMutProfile = cell(height(loopMuts),1) ;
            
            % covert the mutations to a double
            mutatedSamples = ~cellfun(@isempty,loopMuts{:,:}) ;
            
            % annotate the mutations in samples
            curMutProfile( mutatedSamples(:,1)) =  ...
                strcat( loopMuts.Properties.VariableNames(1), ' Mutated') ;
            curMutProfile( mutatedSamples(:,2)) =  ...
                strcat( loopMuts.Properties.VariableNames(2), ' Mutated') ;
            curMutProfile( all(mutatedSamples,2)) = {'Both Mutated'} ;
            curMutProfile( ~any(mutatedSamples,2) ) = {'Not Mutated'} ;
            
            % ================== Surival Analysis =================
            % survival analysis for abacavir metabolism vs non abacavir
            % metabolism
            
            % Get the Overall Survival Data and the Disease Free Survival
            % Data and delete the missing low from the data
            if strcmp(clinicalOutcomes(jj),'overallSurvival')
                OsData = [curClinical.OS_MONTHS,curClinical.OS_STATUS , ...
                    curMutProfile] ;
                OsData(any(cellfun(@isempty,OsData),2),:) = [] ;
                
            else
                % create for the data for disease free survival: first make
                % the disease free data compatible with the matSurv
                % function
                OsData = [curClinical.DFS_MONTHS, ...
                    strrep(regexprep(curClinical.DFS_STATUS,'/(\w+)',''),...
                    'Recurred', 'Relapsed') ,curMutProfile ] ;
                OsData(any(cellfun(@isempty,OsData),2),:) = [] ;
            end
            
            % check if the cancer study had overall survival data
            if all( cellfun(@isempty, OsData(:,1)) )
                break ;
            end
            
            % Anonotate the groups to either pathway mutated or pathway
            % unmutated and perferom K-M Survival Analysis
            groups = OsData(:,3)  ;
            
            % ========== PERFORM OVERALL SURVIVAL ANALYSIS =============
            [logRankP, ~, OsStats] = MatSurv( str2double(OsData(:,1)), ...
                lower(OsData(:,2)) , groups, 'NoRiskTable',true ,...
                'NoPlot',false,'PairWiseP',true ,...
                'setLegendWithNumbers',true );
            
            % here is the current row
            curRow = ii;
            
            % put the results in a table
            if strcmp(clinicalOutcomes(jj),'overallSurvival')
                % add the data to a table
                osPanTable.GeneNames(curRow) = survStudies.GeneNames(ii);
                osPanTable.pValue(curRow) = logRankP ;
                
                % add the meadian survival to the table
                osPanTable.BothMutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    ismember(OsStats.GroupNames,'Both Mutated')) ;
                osPanTable.NoneMutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    ismember(OsStats.GroupNames,'Not Mutated')) ;
                osPanTable.Gene1_Mutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    contains(OsStats.GroupNames, ...
                    extractBefore(osPanTable.GeneNames(curRow),'-') ) ) ;
                osPanTable.Gene2_Mutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    contains(OsStats.GroupNames, ...
                    extractAfter(osPanTable.GeneNames(curRow),'-') ) ) ;
                osPanTable.Pattern(curRow) = survStudies.corType(ii) ;
            else
                % add the data to a table
                dfsPanTable.GeneNames(curRow) = survStudies.GeneNames(ii);
                dfsPanTable.pValue(curRow) = logRankP ;
                
                % add the values to the tablel
                dfsPanTable.BothMutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    ismember(OsStats.GroupNames,'Both Mutated')) ;
                dfsPanTable.NoneMutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    ismember(OsStats.GroupNames,'Not Mutated')) ;
                dfsPanTable.Gene1_Mutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    contains(OsStats.GroupNames, ...
                    extractBefore(dfsPanTable.GeneNames(curRow),'-') ) ) ;
                dfsPanTable.Gene2_Mutated(curRow) = ...
                    OsStats.MedianSurvivalTime( ...
                    contains(OsStats.GroupNames, ...
                    extractAfter(dfsPanTable.GeneNames(curRow),'-') ) ) ;
                dfsPanTable.Pattern(curRow) = survStudies.corType(ii) ;
            end
            
            % get the os data for the current cancer study
            osPairwise = struct2table( OsStats.ParwiseStats ) ;
            osPairwise.GroupNames = OsStats.ParwiseName ;
            osPairwise = sortrows(osPairwise,'p_MC','ascend');
            osPairwise = addvars( osPairwise, ...
                repmat( cellstr( survStudies.GeneNames{ii}), ...
                height(osPairwise),1),  ...
                'NewVariableNames',{'GeneNames'},'Before',1) ;
            
            % annotate the plot
            set(gca,'LineWidth',1.5,'FontSize',12,'FontWeight','bold',...
                'TickDir','out')
            
            if strcmp(clinicalOutcomes(jj),'overallSurvival')
                % annotate the plots
                figName = ['Pancancer OS: ',survStudies.GeneNames{ii},...
                    ' (', char(survStudies.corType(ii)) ,')'] ;
                title(figName,'Fontsize',16,'FontWeight','bold')
                
                % add the data to a table
                osPanMultiTable = [osPanMultiTable ; osPairwise ] ;
                
                % save the figures
                saveas(gcf,[replace(figName,':','_'),'.fig'],'fig')
                saveas(gcf,[replace(figName,':','_'),'.png'],'png')
            else
                figName = ['Pancancer DFS: ',survStudies.GeneNames{ii}, ...
                    ' (', char(survStudies.corType(ii)) ,')'] ;
                title(figName, 'Fontsize',16,'FontWeight','bold')
                
                % add the data to a table
                dfsPanMuliTable = [dfsPanMuliTable ; osPairwise ] ;
                
                % save the figures
                saveas(gcf,[replace(figName,':','_'),'.fig'],'fig')
                saveas(gcf,[replace(figName,':','_'),'.png'],'png')
            end
        end
    end
    
    % add the adjusted p values to the table
    osPanMultiTable.adjPvalue = mafdr(osPanMultiTable.p_MC ,'BHFDR',true);
    dfsPanMuliTable.adjPvalue = mafdr(dfsPanMuliTable.p_MC , 'BHFDR',true);
    
    % remove the instances where the sample sizes in atleast one group is
    % less than 10 and sort the rows of the tables
    osPanMultiTable = sortrows(osPanMultiTable ,'adjPvalue','ascend') ;
    dfsPanMuliTable = sortrows(dfsPanMuliTable ,'adjPvalue','ascend') ;
    
    % save the data to a table
    writetable(osPanMultiTable,'Clinical Outcomes Per Cancer.xlsx',...
        'Sheet','panCancer MultipCompare OS')
    writetable(dfsPanMuliTable,'Clinical Outcomes Per Cancer.xlsx',...
        'Sheet','PanCancer MultiCompare DFS')
    
    % also process the non multicompare results
    % remove the rows without p values add the adjusted pvalues
    osPanTable( isnan(osPanTable.pValue ),: ) = [] ;
    dfsPanTable( isnan(dfsPanTable.pValue), :) = [] ;
    
    osPanTable.adjPvalue = mafdr(osPanTable.pValue ,'BHFDR',true);
    dfsPanTable.adjPvalue = mafdr(dfsPanTable.pValue , 'BHFDR',true);
    
    % remove the instances where the sample sizes in atleast one group is
    % less than 10 and sort the rows of the tables
    osPanTable = sortrows(osPanTable ,'adjPvalue','ascend') ;
    dfsPanTable = sortrows(dfsPanTable ,'adjPvalue','ascend') ;
    
    % save the data to a table
    writetable(osPanTable,'Clinical Outcomes Per Cancer.xlsx','Sheet',...
        'PanCancer OS')
    writetable(dfsPanTable,'Clinical Outcomes Per Cancer.xlsx','Sheet',...
        'PanCancer DSF')
    
    fprintf('\n Done with survival analysis \n\n')
else
    dfsPanTable = readtable('Clinical Outcomes Per Cancer.xlsx','Sheet',...
        'PanCancer DSF') ;
    osPanTable = readtable('Clinical Outcomes Per Cancer.xlsx','Sheet',...
        'PanCancer OS') ;
    dfsPanMuliTable = readtable('Clinical Outcomes Per Cancer.xlsx',...
        'Sheet','PanCancer MultiCompare DFS') ;
    osPanMultiTable = readtable('Clinical Outcomes Per Cancer.xlsx',...
        'Sheet','panCancer MultipCompare OS') ;
end

clear tableH logRankP DFSstats groups dfsData OsData ...
    curPathawayAltersMutants curStudyClinical curPathwayGenes ...
    curPathway curGeneAlters curMuts curCancer curCNA  curGeneAlters ...
    locCurPathway curRow clinicalOutcomes

%% Disease Network and Complexity 

% here are the studies
runThis = false ;

if runThis == true
    
    myStudies = unique(cellstr(mutTable.CancerStudy));
    
    % preallocate the adjucency matrix
    mutCorTable = table('Size',[ length(myStudies) , length(myStudies)],...
        'VariableType', repmat({'double'},1,length(myStudies) ), ...
        'VariableNames',myStudies) ;
    mutCorTable = addvars(mutCorTable, myStudies , 'Before', 1, ...
        'NewVariableNames',{'CancerStudy'}) ;
    
    % along the coloumns
    for ii = 1:length(myStudies)
        
        fprintf('\n Calculating Corr2 for %s study number %d of %d\n', ...
            myStudies{ii}, ii, length(myStudies) )
        
        % here is the inner loop
        for jj = 1:length(myStudies)
            
            % get data for the first cancer
            cancer1 = mutTable{mutTable.CancerStudy ==myStudies{ii},2:end};
            cancer2 = mutTable{mutTable.CancerStudy ==myStudies{jj},2:end};
            
            % check the size of the data
            if size(cancer1,1) < size(cancer2,1)
                cancer2 = cancer2(1:size(cancer1,1), :) ;
            else
                cancer1 = cancer1(1:size(cancer2,1), :) ;
            end
            
            % calculate the similar between two cancer
            corVar = corr2(cancer1, cancer2) ;
            
            % add to the table
            mutCorTable{ii,jj+1} = corVar;
        end
    end
    
end

%% Plot some oncoprints

% here are the cancer 
oncoCancer = {'HNSC','PAAD','ESCA','GBM','KIRP','MM','MPN','AMPCA'} ;

% create the colors for the plots and save the colors 
theColors.mutColors = [0.9 0.9 0.9 ; 0.1000 0.6000 0.2000; ...
     0.49,0.18,0.56 ; 0.93,0.69,0.13 ;0.95, 0.05 0.05 ; 0.07,0.62,1.00;...
     0.05 0.05 0.05];

% here is the global variable that controls the time number 
global plotTime
      
for ii = 1:length(oncoCancer)
    
    % here are the mutations
    curMuts = mutations( mutations.CancerStudy == oncoCancer{ii}, :);
    
    % get the data to be plotted and convert to categories
    Alters = curMuts{:,3:end}' ;
    
    % let reduce the mutation data the to 15 mutated genes
    [~, top15AlteredGene ] = maxk(sum(~cellfun(@isempty,Alters),2),15) ;
    Alters = Alters(top15AlteredGene,:) ;
    
    % get the row names
    rowNames = curMuts.Properties.VariableNames(3:end)';
    rowNames = rowNames(top15AlteredGene) ;
     
    % now convert the missing cell to 'NA'
    Alters(cellfun(@isempty,Alters)) = {'NA'};
    Alters = categorical(Alters,{'NA','SNP','DEL','INS'}) ; % DNP
    
    % get the categories in the data and return only the categories with
    % mutations in the dataset
    cartsInMuts = table( categories( Alters(:) ), ...
        countcats( Alters(:) ) ,'VariableNames', {'Alteration','Count'} );
    cartsInMuts(cartsInMuts.Count == 0 , : ) = [] ;
    
    % now convert the alterations to double
    Alters = double(Alters) ;
    
    % flip the data 
    Alters = flipud(Alters)' ;
    rowNames = flipud(rowNames);
    
    % need to arrange matrix according column one here
    for ss = 1:size( Alters,2)
        Alters = sortrows( Alters,ss,'Descend');
    end
    
    % take back to the original shape
    Alters = Alters' ;
     
    % it turn out that cell position that have multiple alteratins will
    % become NaN These will become 7 (max = 6) + 1
    Alters(isnan(Alters)) = max(Alters,[],'all')+1 ;
    
    % PLOT THE COMPLEX HEAT MAP 
    plotTime = ii;
    exitPos = oncoPrint(Alters, theColors.mutColors, rowNames, true) ;
    
    % add the title to the plot
    text(0.5,4.95,oncoCancer{ii},'FontSize',15,'FontWeight','bold', ...
        'HorizontalAlignment','center','Units','normalized')
    
    % get the alterations that are present in the data that will be use to plot
    % the data
    plotNames = [ {'Not Altered';'Single Nucleotide Polymorphism'; ...
        'Deletion';'Insertion';'Amplification';'Deep Deletion';'Multiple'} ,...
        {'NA';'SNP';'DEL';'INS';'AMP';'LOSS';'Multiple'} ] ;
    
    % return only the groups that are available in the data for plotting
    plotNamesAvail = plotNames( ...
        ismember( plotNames(:,2) , cartsInMuts.Alteration ),1 ) ;
    plotNamesAvail = [ plotNamesAvail; 'Multiple'] ;
    
    % now get the colors that are available in the mutations data and dont
    % forget the add the colors for the multiple groups
    theseColors = ismember( plotNames(:,2) ,cartsInMuts.Alteration ) ;
    theseColors(end) = true ;
    
    % create a legend for the colour in the main plot
    createLegendInternal( 0.5,0.88, plotNamesAvail, ...
        theColors.mutColors(theseColors , :) , ...
        'Gene Alterations',[10, 12] , [0.011 ,0.08])
    
    hold off
    
end



%% Co-Occuring Driver Mutations Analysis within Each Cancer 

addpath('/Users/sinkala/Applications/IBM/ILOG/CPLEX_Studio1271/cplex/matlab/x86-64_osx')
addpath('/Users/sinkala/Documents/MATLAB/cancerUKB_snps/mutSig2CVdata')

% get the cancer studies and the mutation frequencies
myStudies = unique(cellstr(mutations.CancerStudy)) ;
mutFreq = results.AcrossCancerMutations ;
all_comdp_results = [] ;

% load the selection data form CELL paper and remove the columns with
% missing data 
mutSelection = readtable('mutations selection data.xlsx') ;
mutSelection(:,all(ismissing(mutSelection))) = [] ;

% load the superpathway in advancer
fprintf('\n Reading Super Pathway Data \n')
ucscPathway = readtable('My_Super_Pathway.xlsx');

% loop over the studies
for ii = 1:length(myStudies)
    
    fprintf('\n Running COMDP analysis for %s cancer #%d of %d\n',...
        char(myStudies{ii}), ii, length(myStudies) ) 
   
    % first create a table to use in the analysis and get the gene names
    % for at each point to return. occurTable should be a double
    occurTable = mutations(mutations.CancerStudy == myStudies{ii}, 3:end);
    
    % get the freqenty mutated genes in the cancer types
    curMutFreq = mutFreq(mutFreq.CancerStudy == myStudies{ii},3:end);
    
    % get the top 10 mutated genes
    numberOfGenes = 10; % CHANGES THIS VALUE
    
    % lets clean up the mutations so that the terrible genes are not
    % included in the analysis
    if exist([myStudies{ii},'_mutsig2CV.txt'],'file')
        % return only the significantly mutated genes
        mutSig = readtable([myStudies{ii},'_mutsig2CV.txt']) ;
        goodGenes = mutSig.gene(mutSig.p < 0.05) ;
        curMutFreq = curMutFreq(:, ismember( ...
            curMutFreq.Properties.VariableNames ,goodGenes) ) ;
        
        % get the top x genes
        [~,locMostFreq] = maxk( curMutFreq{1,:}, numberOfGenes) ;
        mostFreqGenes = curMutFreq.Properties.VariableNames(locMostFreq);
        
        % check that we have more than 10 genes
        if width(curMutFreq) < 10
            % get the freqenty mutated genes in the cancer types
            curMutFreq2 = mutFreq(mutFreq.CancerStudy == ...
                myStudies{ii},3:end);
            
            % remove the genes that are NEVER signifiantly mutated
            theseBad = [ {'CSMD1','CSMD3','NRXN1','NRXN4','CNTNAP2',...
                'CNTNAP4','CNTNAP5','CNTN5','PARK2','LRP1B','PCLO',...
                'MUC16','MUC4','KMT2C','KMT2A','KMT2D','FAT1','FAT2',...
                'FAT3','FAT4'} , mostFreqGenes ] ;
            curMutFreq2 = curMutFreq2(:, ~ismember( ...
                curMutFreq2.Properties.VariableNames ,theseBad) ) ;
            
            % get the top x genes
            [~,locMostFreq] = maxk( curMutFreq2{1,:}, ...
                numberOfGenes - length(mostFreqGenes) ) ;
            mostFreqGenes2 = curMutFreq2.Properties.VariableNames(...
                locMostFreq);
            
            % merge the two datasets
            mostFreqGenes = [mostFreqGenes , mostFreqGenes2] ;
        end
        
    else
        % remove the genes that are NEVER signifiantly mutated
        theseBad = {'CSMD1','CSMD3','NRXN1','NRXN4','CNTNAP2','CNTNAP4',...
            'CNTNAP5','CNTN5','PARK2','LRP1B','PCLO','MUC16','MUC4', ...
            'KMT2C','KMT2A','KMT2D','FAT1','FAT2','FAT3','FAT4'} ;
        curMutFreq = curMutFreq(:, ~ismember( ...
            curMutFreq.Properties.VariableNames ,theseBad) ) ;
        
        % get the top x genes
        [~,locMostFreq] = maxk( curMutFreq{1,:}, numberOfGenes) ;
        mostFreqGenes = curMutFreq.Properties.VariableNames(locMostFreq) ;
    end
  
    % return only those genes
    occurTable = occurTable(:,mostFreqGenes);
    
    % get the genes names
    occurGeneNames = occurTable.Properties.VariableNames;
    
    % get t
    occurTable = double( ~cellfun(@isempty, occurTable{:,:}) );
    
    % set the eta values
    etaValue = 10:-3:1 ;
    
    % now run the algorythm IBM CPLEX location must be added to path for
    % this to work
    for ee = 1:length(etaValue)
        comdp_results = CoMDP(occurTable,numberOfGenes,etaValue(ee),1,[]);
        
        % check that one of the genes sets have 1 genes only 
        if comdp_results(5) ~= 1 || comdp_results(5) ~= 9
           break 
        end
    end
    
    % convert the results to a table 
    comdp_results = [array2table(occurGeneNames), ...
        array2table(comdp_results(length(occurGeneNames)+1:end) )] ;
    
    % add variable names to the created table and add genes to the table
    table_variables = strcat( repmat({'Gene'},length(occurGeneNames),1),...
        split(num2str(1:length(occurGeneNames))) ) ;
    table_variables2 = {'Weight','Gene_Set1_p','Gene_Set2_p',...
        'Co_Occurrence_Sig','Set1_Genes','Set2_Genes',...
        'Set1_Coverage','Set2_Coverage','Common_Coverage',...
        'Union_Coverage','Co_Occurrence_Ratio'};
    table_variables = [table_variables' , table_variables2] ;
    comdp_results.Properties.VariableNames = table_variables ;
    
    % define where set1 genes end.
    split_site = comdp_results.Set1_Genes(1) ;
    
    % add the comdp results to the growing table 
    comdp_results = addvars(comdp_results, myStudies(ii), 'Before',1,...
        'NewVariableNames',{'CancerStudy'}) ;
    all_comdp_results = [all_comdp_results ; comdp_results ] ;
    
    % add zeroes to the split size and the x label for the figure
    matrixZ = [ occurTable(:,1:split_site), ...
        zeros(size(occurTable,1),1), occurTable(:,split_site+1:end)] ;
    theXlabel = [occurGeneNames(:,1:split_site),{''},...
        occurGeneNames(:,split_site+1:end)] ;
    
    % now make the plot
    figure()
    hold on
                
    for zz = 1:size(matrixZ,2) % loop over the data matrix
        
        % need to arrange matrix according column one here
        for ss = size(matrixZ,2):-1:1
            matrixZ = sortrows(matrixZ,ss,'Descend');
        end
        
        sub_data = matrixZ(:,zz);
        for xx = 1:length(sub_data) % go down the data array
            if sub_data(xx,1) == 1
                xVars = xx;% get the index of the mutation
                yVars = zz-0.5;

                % need to check if the mutation co-exist with another in
                % the same gene set first need to check in the split site
                % has been past
                if zz < split_site + 1 % before the split site
                    for mm = 1:split_site
                        if  sub_data(xx,1) == matrixZ(xx,mm) && zz ~= mm
                            plot([yVars yVars+1], [xVars xVars], 'Color',...
                                [0.9290 0.6940 0.1250],'LineWidth',3)
                            break
                        else
                            plot([yVars yVars+1], [xVars xVars],'Color',...
                                [0.3010 0.7450 0.9330],'LineWidth',3)
                        end
                    end
                else % after the split is passed comparision changes
                    % need to arrange matrix according column one here
                    for mm = split_site+2:size(matrixZ,2) %because there are zeroes
                        if  sub_data(xx,1) == matrixZ(xx,mm) && zz ~= mm
                            plot([yVars yVars+1], [xVars xVars],'Color', ...
                                [0.9290 0.6940 0.1250],'LineWidth',3)
                            break
                        else
                            plot([yVars yVars+1], [xVars xVars], 'Color',...
                                [0.3010 0.7450 0.9330],'LineWidth',3)
                        end
                    end
                end
                
                % change the figure
                axis([ 0 size(matrixZ,2)+1 0 size(matrixZ,1)+1]);
                set(gca,'XAxisLocation','top','YAxisLocation','left',...
                    'ydir','reverse','XTick',1:length(theXlabel),...
                    'XTickLabel',theXlabel,'LineWidth',1.5,...
                    'FontSize',14 ,'TickDir','out');
            end
        end
    end
    
    % add the label and save the figure
    ylabel('Samples','FontSize',14)
    figName = sprintf('Mutated Driver Pathways - %s', myStudies{ii});
    title(myStudies{ii},'FontSize',16,'FontWeight','bold')
    
    % add the selection part the figure below this will be a bar graph with
    % axis removed 
    
    % check if the study in present in the mutation selection data 
    if any(ismember(mutSelection.Properties.VariableNames,myStudies{ii}))
        
        % get the genes from the table 
        curSelection = mutSelection( ...
            ismember(mutSelection.gene,occurGeneNames), ...
            [{'gene'},myStudies{ii}]) ;
        
        % add the genes that are missing
        misnGenes = setdiff( occurGeneNames, curSelection.gene) ;
        misnGenes = [misnGenes',num2cell(ones(length(misnGenes),1))] ;
        curSelection = [curSelection;  misnGenes] ;
        
        % add the split size
        splitSiteLoc = [{''}, ones(1,1) ] ;
        curSelection = [curSelection;  splitSiteLoc] ;
        
        % sort the table according to how the genes appear in the
        % occurGenes
        [~,locThem] = ismember( theXlabel ,curSelection.gene) ;
        curSelection = curSelection(locThem, :) ;
        
        % add values and bar graph size
        curSelection.BarSize = double(~ismissing(curSelection.gene));
        
        % plot the bar graph [0.1300 0.1100 0.7750 0.7280]
        axes('position',[0.1300 0.0500 0.7750 0.05] );
        bv = bar(curSelection.BarSize,0.9,'EdgeColor',[1 1 1]) ;
        
        % edit some plot features
        set(gca,'GridColor',[1 1 1], ...
            'XLim', [0 height(curSelection)+1 ], ...
            'XColor',[1 1 1] ,'XTick',[],'YColor',[1 1 1],'YTick',[])
        
        % add the y label
        ylabel("+ Selection",'Color','k','FontSize',14)
        hYLabel = get(gca,'YLabel');
        set(hYLabel,'rotation',0,'VerticalAlignment','middle', ...
            'HorizontalAlignment','right')
        
        % change the colors of the bars 
        bv.FaceColor = 'flat';
        
        for jj = 1:height(curSelection)
            % change the face color
            if curSelection.(2)(jj) < 0.001
                bv.CData(jj,:) = [0.635 0.078 0.184];
            elseif curSelection.(2)(jj) < 0.01
                bv.CData(jj,:) = [0.850 0.325 0.098 ];
            elseif curSelection.(2)(jj) < 0.05
                bv.CData(jj,:) = [0.929 0.694 0.125] ;
            else
                bv.CData(jj,:) = [0.7 0.7 0.7];
            end
        end
    end
    
    % save to teh file
    saveas(gcf,[figName,'.png'],'png')
    saveas(gcf,[figName,'.fig'],'fig')
    hold off
    
    % here are the genes involved in the cancer study
    curGenes = [occurGeneNames(:,1:split_site),{''},...
        occurGeneNames(:,split_site+1:end)]' ;
    
    % create a mutation network
    diNetwork = createNetworkDataInternal(curGenes,ucscPathway) ;
    
    hold on
    title(myStudies{ii})
    % save to teh file
    figName = sprintf('Pathways - %s', myStudies{ii}) ;
    
    saveas(gcf,[figName,'.png'],'png')
    saveas(gcf,[figName,'.fig'],'fig')
    hold off
    
end

% write the comdp results to excel 
writetable(all_comdp_results,'COMDP_results.xlsx') ;

clear theseBad goodGenes jj ii bv hYLabel curSelection figName ...
    misnGenes locThem zz values y matrixZ curMutFreq split_site ...
    table_variables numberOfGenes occurTable locMostFreq mutSig ...
    etaValue

%% Create a legend for Comdp results 

% specify where to plot the legend and the font size and the width of the
% rectangle and the text box
figure()
yPoint = 0.90 ; xStart = 0.5 ; myLgdTitle = 'Mutation Pattern';
fontSizes = [10,12];
rectAndTextBox = [0.01 ,0.10] ;
legendLabels = {'Co-occurence','Exclusive'};

% create the legend
createLegendInternal(yPoint, xStart, legendLabels , ...
    [0.9290 0.6940 0.1250; 0.3010 0.7450 0.9330], myLgdTitle, ...
    fontSizes ,rectAndTextBox)

% add a legend to figure  using the create legend function
% First specify the legend labels and yPoint and xStart
legendLabels = {'< 0.001','< 0.01','< 0.05','>= 0.05 or NA'} ;

% specify where to plot the legend and the font size and the width of the
% rectangle and the text box
yPoint = 0.80 ; myLgdTitle = 'Positive Selection';
selecColors = [0.635 0.078 0.184; 0.850 0.325 0.098; 0.929 0.694 0.125;...
    0.7 0.7 0.7];

% create the legend
createLegendInternal(yPoint, xStart, legendLabels , ...
   selecColors,myLgdTitle ,fontSizes ,rectAndTextBox)

% do the legend of the headmap colors
yPoint = 0.64 ;
patternColors = [0.9290 0.6940 0.1250; 0.3010 0.7450 0.9330];
createLegendInternal(yPoint, xStart, ...
    {'Co-occurence','Exclusive'}, patternColors,'Interation Network', ...
    fontSizes)

%% Run the co-occuring analysis across all samples

% load the selection data form CELL paper and remove the columns with
% missing data
mutSelection = readtable('mutations selection data.xlsx') ;
mutSelection(:,all(ismissing(mutSelection))) = [] ;

% load the superpathway in advancer
fprintf('\n Reading Super Pathway Data \n')
ucscPathway = readtable('My_Super_Pathway.xlsx');

fprintf('\n Running Pancancer COMDP analysis\n' )

% first create a table to use in the analysis and get the gene names
% for at each point to return. occurTable should be a double
occurTable = mutations(:, 3:end);

% get the freqenty mutated genes in the cancer types
curMutFreq = mutFreq(:,3:end);

% get the top 10 mutated genes
numberOfGenes = 6; % CHANGES THIS VALUE

% remove the genes that are NEVER signifiantly mutated
theseBad = {'CSMD1','CSMD3','NRXN1','NRXN4','CNTNAP2','CNTNAP4',...
    'CNTNAP5','CNTN5','PARK2','LRP1B','PCLO','MUC16','MUC4', ...
    'KMT2C','KMT2A','KMT2D','FAT1','FAT2','FAT3','FAT4'} ;
curMutFreq = curMutFreq(:, ~ismember( ...
    curMutFreq.Properties.VariableNames ,theseBad) ) ;

% get the top x genes
[~,locMostFreq] = maxk( curMutFreq{1,:}, numberOfGenes) ;
mostFreqGenes = curMutFreq.Properties.VariableNames(locMostFreq) ;

% return only those genes
occurTable = occurTable(:,mostFreqGenes);

% delete all the empty rows 
occurTable( all(cellfun(@isempty,occurTable{:,:}),2),:) = [];

% get the genes names
occurGeneNames = occurTable.Properties.VariableNames;

% get t
occurTable = double( ~cellfun(@isempty, occurTable{:,:}) );

% set the eta values
etaValue = 6:-3:1 ;

% now run the algorythm IBM CPLEX location must be added to path for
% this to work
for ee = 1:length(etaValue)
    comdp_results = CoMDP(occurTable,numberOfGenes,etaValue(ee),1,[]);
    
    % check that one of the genes sets have 1 genes only
    if comdp_results(5) ~= 1 || comdp_results(5) ~= 9
        break
    end
end

% convert the results to a table
comdp_results = [array2table(occurGeneNames), ...
    array2table(comdp_results(length(occurGeneNames)+1:end) )] ;

% add variable names to the created table and add genes to the table
table_variables = strcat( repmat({'Gene'},length(occurGeneNames),1),...
    split(num2str(1:length(occurGeneNames))) ) ;
table_variables2 = {'Weight','Gene_Set1_p','Gene_Set2_p',...
    'Co_Occurrence_Sig','Set1_Genes','Set2_Genes',...
    'Set1_Coverage','Set2_Coverage','Common_Coverage',...
    'Union_Coverage','Co_Occurrence_Ratio'};
table_variables = [table_variables' , table_variables2] ;
comdp_results.Properties.VariableNames = table_variables ;

% define where set1 genes end.
split_site = comdp_results.Set1_Genes(1) ;

% add the comdp results to the growing table
comdp_results = addvars(comdp_results, {'Pancancer'}, 'Before',1,...
    'NewVariableNames',{'CancerStudy'}) ;
% add zeroes to the split size and the x label for the figure

matrixZ = [ occurTable(:,1:split_site), ...
    zeros(size(occurTable,1),1), occurTable(:,split_site+1:end)] ;
theXlabel = [occurGeneNames(:,1:split_site),{''},...
    occurGeneNames(:,split_site+1:end)] ;

% need to arrange matrix according column one here
for ss = size(matrixZ,2):-1:1
    matrixZ = sortrows(matrixZ,ss,'Descend');
end

%% now make the plot
figure()
hold on

split_site = find( cellfun(@isempty,theXlabel), true) ;

for zz = 1:size(matrixZ,2) % loop over the data matrix
    
    % get the array
    sub_data = matrixZ(:,zz);
    
    % ge the mutations from the data 
    xVars = repmat(zz,1,length(sub_data)) ;
    xVars = [xVars ; xVars+1] ;
    xVars =  xVars-0.5 ;
    yVars = length(sub_data):-1:1;
    yVars = yVars ;
    yVars = [yVars ; yVars] ;
    
    % get teh co-occuring data
    if zz < split_site
        theExclusive = sum( matrixZ(:,1:split_site) ,2) > 1 ;
    else
        theExclusive = sum( matrixZ(:,split_site+1:end) ,2) > 1 ;
    end
    
    % return only the mutated samples
    xVars = xVars(:,sub_data == 1) ;
    yVars = yVars(:,sub_data == 1) ;
    theExclusive = theExclusive(sub_data == 1) ;
    
    % need to check if the mutation co-exist with another in
    % the same gene set first need to check in the split site
    % has been past
    if zz ~= split_site % before the split site
        plot( xVars(:,~theExclusive),yVars(:,~theExclusive),'Color',...
            [0.3010 0.7450 0.9330],'LineWidth',1)
        
        plot( xVars(:,theExclusive),yVars(:,theExclusive), 'Color',...
            [0.9290 0.6940 0.1250],'LineWidth',1)
    else
        plot(xVars,yVars,'Color',[1 1 1],'LineWidth',1)
    end
    
end

% change the figure
axis([ 0 size(matrixZ,2)+1 0 size(matrixZ,1)+1]);
set(gca,'XAxisLocation','top','YAxisLocation','left',...
    'XTick',1:length(theXlabel),'YLim', [1 ,size(matrixZ,1)], ...
    'XTickLabel',theXlabel,'LineWidth',1.5,...
    'FontSize',14 ,'TickDir','out');

% add the label and save the figure
ylabel('Samples','FontSize',14)
figName = 'Pancancer Mutated Driver Pathways' ;
title('Pancancer','FontSize',16,'FontWeight','bold')

%% check if the study in present in the mutation selection data
% get the genes from the table
curSelection = mutSelection( ...
    ismember(mutSelection.gene,occurGeneNames),{'gene','PANCANCER'}) ;

% add the genes that are missing
misnGenes = setdiff( occurGeneNames, curSelection.gene) ;
misnGenes = [misnGenes',num2cell(ones(length(misnGenes),1))] ;
curSelection = [curSelection;  misnGenes] ;

% add the split size
splitSiteLoc = [{''}, ones(1,1) ] ;
curSelection = [curSelection;  splitSiteLoc] ;

% sort the table according to how the genes appear in the
% occurGenes
[~,locThem] = ismember( theXlabel ,curSelection.gene) ;
curSelection = curSelection(locThem, :) ;

% add values and bar graph size
curSelection.BarSize = double(~ismissing(curSelection.gene));

% plot the bar graph [0.1300 0.1100 0.7750 0.7280]
axes('position',[0.1300 0.0500 0.7750 0.05] );
bv = bar(curSelection.BarSize,0.9,'EdgeColor',[1 1 1]) ;

% edit some plot features
set(gca,'GridColor',[1 1 1], ...
    'XLim', [0 height(curSelection)+1 ], ...
    'XColor',[1 1 1] ,'XTick',[],'YColor',[1 1 1],'YTick',[])

% add the y label
ylabel("+ Selection",'Color','k','FontSize',14)
hYLabel = get(gca,'YLabel');
set(hYLabel,'rotation',0,'VerticalAlignment','middle', ...
    'HorizontalAlignment','right')

% change the colors of the bars
bv.FaceColor = 'flat';

for jj = 1:height(curSelection)
    % change the face color
    if curSelection.(2)(jj) < 0.001
        bv.CData(jj,:) = [0.635 0.078 0.184];
    elseif curSelection.(2)(jj) < 0.01
        bv.CData(jj,:) = [0.850 0.325 0.098 ];
    elseif curSelection.(2)(jj) < 0.05
        bv.CData(jj,:) = [0.929 0.694 0.125] ;
    else
        bv.CData(jj,:) = [0.7 0.7 0.7];
    end
end

% save to teh file
saveas(gcf,[figName,'.png'],'png')
saveas(gcf,[figName,'.fig'],'fig')
hold off

% here are the genes involved in the cancer study
curGenes = [occurGeneNames(:,1:split_site-1),{''},...
    occurGeneNames(:,split_site:end)]' ;

% create a mutation network
diNetwork = createNetworkDataInternal(curGenes,ucscPathway,true) ;

hold on
title('Pancancer')
% save to teh file
figName = 'Pathways - Pancancer' ;

saveas(gcf,[figName,'.png'],'png')
saveas(gcf,[figName,'.fig'],'fig')
hold off

% create another netwokr
diNetwork = createNetworkDataInternal(curGenes,ucscPathway) ;
figName = 'Pathways - Pancancer Less' ;

saveas(gcf,[figName,'.png'],'png')
saveas(gcf,[figName,'.fig'],'fig')
hold off

%% How Do these Mutations Affect Drug Sensitivity 










%% *************** Here are some internal function ********************

% ********************** Here is the internal funciton *****************
% get the all genes in are in the 3 pathways from the ucsc pathway

function netGenes = createNetworkDataInternal(netGenes,ucscPathway,...
    includeAllInNetwork)

% change the interactions to include in the network
if nargin == 2
     includeAllInNetwork = false;
end

% get first and secton set proteins
locEmpty = find( cellfun(@isempty,netGenes), true) ;
genes1 = netGenes(1:locEmpty-1) ;
genes2 = netGenes(locEmpty+1:end) ;

% remove the missing genes and create a network
netGenes(cellfun(@isempty,netGenes)) = [] ;
ogmTOR = netGenes;

% here are the interactions 
netGenes = ucscPathway( contains(ucscPathway.Protein1,netGenes) | ...
    contains(ucscPathway.Protein2, netGenes) , :) ;

% Now create the mTOR pathaway

% I will have to start with a simpler (smaller) graph
% create a graph from edge: first delete the selfloop nodes
selfLoop = strcmpi(netGenes.Protein1 , netGenes.Protein2) ;
netGenes(selfLoop,:) = [] ;

% get only the unique genes 
netGenes = unique(netGenes) ;

% create table for yED that also contains the origanal proteins and also
% add the differential gene expression log p-value to be used to colour the
% notes
ogProteins = contains(netGenes.Protein1 ,ogmTOR) ;
netGenes.NodeInGO = double(ogProteins) ;

% remove that bad arrow from the data
bad = contains(netGenes.Interaction,'-t>');
netGenes.Interaction(bad,1) = {'->t'};

if  includeAllInNetwork == false
    % return only the proteins are present in the input protein list
    netGenes = netGenes(ismember(netGenes.Protein1,ogmTOR) & ...
        ismember(netGenes.Protein2,ogmTOR), :) ;
end

% now create a graph
mtorGraph = digraph(netGenes.Protein1 , netGenes.Protein2);
mtorGraph.Edges.Interaction = netGenes.Interaction ;

% plot the graph
figure()
if  includeAllInNetwork == false
    hMTOR = plot(mtorGraph,'layout','force','usegravity',true,...
        'MarkerSize',40,'ArrowSize', 10,'EdgeAlpha',0.80 ,...
        'LineWidth', 0.5000,'NodeFontSize',15,'ArrowPosition',0.8);
    set(gca,'FontSize',16,'FontWeight','bold','visible', 'off')
else
    hMTOR = plot(mtorGraph,'layout','force','usegravity',true,...
        'MarkerSize',3,'ArrowSize', 3,'EdgeAlpha',0.80 ,...
        'NodeFontSize',15,'ArrowPosition',0.8);
    set(gca,'FontSize',16,'FontWeight','bold','visible', 'off')
end

% get the nodes of cancers and highlight them
myNodes = mtorGraph.Nodes.Name(ismember(mtorGraph.Nodes.Name,genes1));
highlight(hMTOR,myNodes,'NodeColor',[0.9290 0.6940 0.1250], ...
    'MarkerSize',35,'NodeFontSize',15)

myNodes = mtorGraph.Nodes.Name(ismember(mtorGraph.Nodes.Name,genes2)) ;
highlight(hMTOR,myNodes,'NodeColor',[0.3010 0.7450 0.9330],...
    'MarkerSize',35,'NodeFontSize',15)
  
hold on
% get the nodes that have edge for interactions from biogrid
allInters =  unique(mtorGraph.Edges.Interaction) ;
for ii = 1:length(allInters)
    cur_inter = allInters(ii,1) ;
    locsG = contains(mtorGraph.Edges.Interaction,cur_inter);
    [sOut,tOut] = findedge(mtorGraph);
    allEdges = [sOut,tOut];
    % check = mtorGraph.Edges(locsG,:) ;
    subGraph = allEdges(locsG,:) ;
    subGraph = reshape( subGraph',1,[]) ;
    % if the interaction is just protein-protein
    if strcmp(cur_inter,'->i')
        highlight(hMTOR,subGraph,'EdgeColor',[0.73 0.49 0.43], ...
            'LineWidth',1.5 ,'LineStyle','--') % ,'ArrowPosition',1)
    elseif strcmp(cur_inter,'->p')
        highlight(hMTOR,subGraph,'EdgeColor','b','LineWidth',2)
    elseif strcmp(cur_inter,'-a>')
        highlight(hMTOR,subGraph,'EdgeColor',[0.32 0.79 0.43],...
            'LineWidth',2)
    elseif strcmp(cur_inter,'-a|')
        highlight(hMTOR,subGraph,'EdgeColor','r','LineWidth',2)
    else
        highlight(hMTOR,subGraph,'EdgeColor',[0.5 0.5 0.5],...
            'LineWidth',1.5)
    end
    
end
hold off
end

% *************************** Internal Function ***********************
% *********************************************************************

% This function processes TCGA data for pancancer studies into single files
% for each dataset for all studies

function [mutations,mafFile,cancerStudies,clinicalData,missingGenes] = ...
    getcBioPortalDataAllStudies(myGenes,mutBias)

% the api seem to be non functional at the moment. So I use a text filed
% that i download from cBioportal to run my analysis

% Get Data from cBioPortal
% Set web API URL (excluding 'webservice.do', trailing slash optional)
cgdsURL = 'http://www.cbioportal.org/';

% check that the cancer studies have been done here -- I am freezing the
% analysis to the current data

if ~exist('cancerStudies_clean.csv','file')
    
    % Get list of available cancer types
    cancerStudies = getcancerstudies(cgdsURL);
    cancerStudies = struct2table(cancerStudies);
    
    % Get the list cancer studies codes & return only Cancer studies that have
    % both mutations and copy number alterations data
    toKeepStudies = false(height(cancerStudies),1) ;
    
    for kk = 1:height(cancerStudies)
        fprintf('\n Checking Genetic Profiles for study number %d: %s \n',...
            kk, cancerStudies.name{kk} )
        
        % check if the study is a TCGA provisional then do away with it
        if contains(cancerStudies.name{kk},'Provisional', ...
                'IgnoreCase',true)
            fprintf('\n This is a Provisional Study - Excluded \n')
            fprintf('\n ========================================== \n\n')
            continue
        end
        
        % remove Non pan cancer TCGA studies because they form duplicate
        % studies in the data
        % check if the study is a TCGA provisional then do away with it
        if contains(cancerStudies.name{kk},'TCGA', 'IgnoreCase',true)
            if ~contains(cancerStudies.name{kk},'PanCancer Atlas', ...
                    'IgnoreCase',true)
                fprintf('\n This is a Non Pan-Cancer Study - Excluded \n')
                fprintf(['\n =======================================',...
                    '================ \n\n'])
                continue
            end
        end
        
        % remove CCLE studies because they are cell line data this removes
        if contains(cancerStudies.name{kk},...
                {'Cell Line','NCI-60','xenograft','Pediatric','Histio',...
                'MIXED','Summit'},'IgnoreCase',true )
            fprintf('\n These are CCLE or NCI data - Excluded \n')
            fprintf(['\n =======================================',...
                '================ \n\n'])
            continue
        end
        
        % get the data from cBioPortal
        geneticProfiles = getgeneticprofiles(cgdsURL, ...
            cancerStudies.cancerTypeId{kk});
        
        % use the mutation biase to get all the studies with mutation
        if mutBias == true
            % find out if the data contains mutations
            mutsInData = sum( contains(geneticProfiles.geneticProfileName, ...
                {'Mutations'},'IgnoreCase',true ) ) ;
            mutsComp = 1 ;
        else
            % find out if the data contains mutations
            mutsInData = sum( contains(geneticProfiles.geneticProfileName, ...
                {'Mutations','copy-number'},'IgnoreCase',true ) ) ;
            mutsComp = 2;
        end
        
        % now get the data
        if mutsInData >= mutsComp % if the data has copy number data and mutations
            toKeepStudies(kk) = true;
            fprintf('\n PASSED!! The study has mutations and copy number data \n')
        else
            fprintf('\n The study has NO mutations and copy number data \n')
        end
        fprintf('\n =============================================== \n\n')
    end
    
    % here are the cancer studies htat we need get data for
    cancerStudies = cancerStudies(toKeepStudies,:) ;
    
    % also remove the duplicate studies 
    duplicateStudies = readtable('duplicateStudies.xlsx');
    
    % remove the duplicate studies
    cancerStudies(ismember(cancerStudies.name, ...
        duplicateStudies.duplicateStudies), :) = [] ;
    
    % remove the pediatric studies 
    pediatricStudies = readtable('pediatricStudies.xlsx');
    
    % remove the pediatric studies
    cancerStudies(ismember(cancerStudies.name, ...
        pediatricStudies.pediatricStudies), :) = [] ;
    
    % remove the sequenced studies 
    cancerStudies( contains( cancerStudies.description, ...
        'Targeted sequencing'), :) = [] ;
    
    % add the cancer codes to the data
    cancerStudies = addvars(cancerStudies, strtrim( ...
        upper(extractBefore(cancerStudies.cancerTypeId,'_'))) ,...
        'Before',1 ,'NewVariableNames','cancerCode') ;
    
    % save the cancer data
    writetable(cancerStudies,'cancerStudies_clean.csv');
    
else
    cancerStudies = readtable('cancerStudies_clean.csv');
end

% *********************************************************************
% get the mutation annotation files - MAF file

% make a directory if it does not exist
if ~exist('allCancerMutations','dir')
    mkdir allCancerMutations
end

% add the path to matlab and change the directory
addpath('/Users/sinkala/Documents/MATLAB/cancerUKB_snps/allCancerMutations')
addpath('/scratch/snkmus003/cancerMuts/allCancerMutations')

cd allCancerMutations

% preallocate the mafFile and the clinical data
mafFile = [] ;
clinicalData = [] ;
mutations = [] ;

% add the data if it does not exist
if ~exist('mafFile_allcancer.csv','file')
    
    % process the data through the loop
    for ii = 1:height(cancerStudies)
        
        % clear the tempMaf at the begining of each iteration 
        clear tempMaf
        
        % get the current cancer study
        cancerCode = cancerStudies.cancerTypeId{ii} ;
        
        % print something to the screen
        fprintf('\nGetting data for study number %d of %d : %s\n', ...
            ii,height(cancerStudies),cancerCode)
        
        % check if the file has been downloaded
        if ~exist( sprintf('%s.tar.gz',cancerCode),'file')
            
            % here is the file name 
            filename = sprintf('%s.tar.gz',cancerCode) ;
            
            % here is the location of the data
            url = sprintf('https://cbioportal-datahub.s3.amazonaws.com/%s.tar.gz',cancerCode) ;
            
            % get the information for cBioportal
            websave(filename,url)
        end
        
        % unzip the file and untar the file if this is not already done
        if ~isfolder(sprintf('%s',cancerCode))
            gunzip(sprintf('%s.tar.gz',cancerCode))
            untar(sprintf('%s.tar',cancerCode))
        end
        
        % change the directory to get the extended mutation data
        cd(sprintf('%s',cancerCode))
        
        % check that the mutation data exists
        if ~exist('data_mutations.txt','file') && ...
                ~exist('data_mutations_extended.txt','file')
            fprintf('\nNo mutation data present\n')
            % change back to the previous directory
            try
                cd('/scratch/snkmus003/cancerMuts/allCancerMutations')
            catch
                cd(['/Users/sinkala/Documents/MATLAB/cancerUKB_snps/',...
                    'allCancerMutations'])
            end
            
            % return to the top of the loop 
            continue
        end
        
        % now read the downloaded dataset of mutations
        try
            tempMaf = readtable('data_mutations_extended.txt');
        catch
            tempMaf = readtable('data_mutations.txt') ;
        end
        
        % check that tempMat exists
        if ~exist('tempMaf','var')
            % change to the top level directory
            change_Dir
            continue
        end
        
        % check that the temp maf has data 
        if isempty('tempMaf')
            % change to the top level directory
            change_Dir
            continue
        end
        
        % some data dont seem to read well so I skip them 
        if ~any(contains(tempMaf.Properties.VariableNames,'Hugo_Symbol'))
            % change to the top level directory 
            change_Dir
            continue
        end
        
        % get the short code of the cancer study
        shortCode = categorical(cellstr(upper( ...
            extractBefore(cancerCode,'_'))) ) ;
        
        % add the cancer type to the tempMaf table then a
        tempMaf = addvars(tempMaf,repmat(shortCode,height(tempMaf),1),...
            'Before',1,'NewVariableNames','CancerStudy') ;
        
        % check that the temp maf has data 
        if isempty('tempMaf') || isnumeric(tempMaf.Hugo_Symbol)
            % change to the top level directory
            change_Dir
            continue
        end
        
        % skip the bad mutation data if all the variables that are required
        % are not found in the data 
        try 
            % return only the required columns
            tempMaf = tempMaf(:,{'CancerStudy','Hugo_Symbol',...
                'NCBI_Build','Chromosome','Start_Position',...
                'End_Position','Strand','Variant_Classification',...
                'Variant_Type','Tumor_Sample_Barcode','HGVSp'}) ;
        catch
            fprintf('\nThe mutation data not nicely formatted\n')
            
            % change to the top level directory
            change_Dir
            continue
        end
        
        % now get the mutations of the consensus cancer genes
        % tempMaf = tempMaf(ismember(tempMaf.Hugo_Symbol, myGenes), :);
        
        % load the clinical data for the current cancer and clean up the if
        % the study has not clinical samples information then I skip the
        % study
        try
            curClin = readtable('data_clinical_sample.txt', ...
                'HeaderLines',4) ;
            curClin.Properties.VariableNames(1) = "SampleIds";
            
            % replace the _ with no space since some studies do not have
            % space in the names therefore can not vertcat 
            curClin.Properties.VariableNames = replace( ...
                curClin.Properties.VariableNames,'_','') ;
            
            try % try to get the data
                % check that the current datasets contains RACE or
                % ETHNICITY of the patients
                if ismember( curClin.Properties.VariableNames,'RACE')
                    % get only the required variable from the clinical data
                    curClin = curClin(:,{'SampleIds','CANCERTYPEDETAILED',...
                        'CANCERTYPE','ONCOTREECODE','RACE'}) ;
                    curClin.Properties.VariableNames(end) = {'ETHNICITY'};
                elseif ismember(curClin.Properties.VariableNames, ...
                        'ETHNICITY')
                    % get only the required variable from the clinical data
                    curClin = curClin(:,{'SampleIds','CANCERTYPEDETAILED',...
                        'CANCERTYPE','ONCOTREECODE','ETHNICITY'}) ;
                else
                    % get the clinical data and add another variable called
                    % ethinicity 
                    curClin = curClin(:,{'SampleIds','CANCERTYPEDETAILED',...
                        'CANCERTYPE','ONCOTREECODE'}) ;
                    
                    % add ethinicity to the table 
                    curClin = addvars( curClin, ...
                        repmat({'Unknown'},height(curClin),1) ,...
                        'NewVariableNames','ETHNICITY') ;
                end
                
            catch
                fprintf('\nThe clinical data not nicely formatted\n')
                % change to the top level directory 
                change_Dir
                continue
            end
            
            % replace the bad named with nicely formated names 
            curClin.Properties.VariableNames(2:end) =  ...
                replace(curClin.Properties.VariableNames(2:end), ...
                curClin.Properties.VariableNames(2:end), ...
                {'CancerTypeDetailed','CancerType','OncoTreeCode','Race'});
        catch
            % change back to the previous directory
            change_Dir
            
            % continue the loop
            continue
        end
        
        % sometimes the samples Ids are double
        if isnumeric(curClin.SampleIds)
            curClin.SampleIds = cellstr( num2str(curClin.SampleIds)) ;
        end
        
        if isnumeric(tempMaf.Tumor_Sample_Barcode)
            tempMaf.Tumor_Sample_Barcode = ...
                cellstr( num2str(tempMaf.Tumor_Sample_Barcode)) ;
        end
        
        % ***************************************************************
        % ETHNICITY AGE
        
        % add to the growing table 
        try
            clinicalData = [clinicalData; curClin] ;
        catch
            fprintf('\nThe clinical data not nicely formatted\n')
            % change to the top level directory
            head(clinicalData,3)
            
            % change back to the previous directory
            change_Dir
            
            continue
        end
        
        % add the tempMaf data to the maf file
        try
            mafFile = [mafFile; tempMaf] ;
        catch
            fprintf('\nThe maf File not nicely formatted\n')
            % change to the top level directory
            head(tempMaf,3)
            
            % change back to the previous directory
            change_Dir
            continue
        end
        
        % change back to the previous directory
        change_Dir
        
        % *************  process the resultant MAF file ***************
        % process the mutations data into a table 
        tempMut = processMAF( tempMaf(:,2:end) );
        
        % now get the mutations of the I only want 
        tempMaf = tempMaf(ismember(tempMaf.Hugo_Symbol,myGenes), :);
        tempMut = [ tempMut(:,1), ...
            tempMut(:,ismember(tempMut.Properties.VariableNames,myGenes))];
        
        % add the tempMaf data to the maf file
        try
            mafFile = [mafFile; tempMaf] ;
        catch
            fprintf('\nThe maf File not nicely formatted\n')
            % change to the top level directory
            head(tempMaf,3)
            
            % change back to the previous directory
            continue
        end
        
        % change the name from SampleIDs to SampleIds to make the name
        % uniform with other data. Also replace - with _
        tempMut.Properties.VariableNames(1) = {'SampleIds'};
        tempMut.SampleIds = strrep(tempMut.SampleIds,'-','_') ;
        
        % add cancer study
        tempMut = addvars(tempMut, ...
            upper( repmat(shortCode,height(tempMut),1) ) ,...
            'Before','SampleIds','NewVariableNames','CancerStudy') ;
        
        % this is different from the copy number data as not all the
        % metabolic RoleInCancer genes are mutated. Therefore I need to add the
        % genes that are not mutated to the table create a table of height
        % = that of tempMut and length = to that of the unmutated genes
        missingGenes = setdiff(myGenes, ...
            tempMut.Properties.VariableNames(3:end));
        dummyMut = array2table( cell(height(tempMut),length(missingGenes)));
        dummyMut.Properties.VariableNames = strrep(missingGenes,'-','_') ;
        tempMut = [tempMut,dummyMut] ;
        
        % add to the growing table
        switch ii
            case ii == 1
                mutations = vertcat(mutations,tempMut) ;
            otherwise
                % [C,ia,ib] = intersect(___) also returns index vectors
                % ia and ib using any of the previous syntaxes.
                % Generally, C = A(ia) and C = B(ib)
                [~,ia,ib] = intersect(mutations.Properties.VariableNames, ...
                    tempMut.Properties.VariableNames,'stable') ;
                mutations = mutations(:,ia);
                tempMut = tempMut(:,ib);
                mutations = vertcat(mutations, tempMut) ;
        end
        
        % remove the file that was downloaded and extracted
        if isfolder('/scratch/snkmus003/cancerMuts/allCancerMutations')
            system(sprintf('rm -r %s %s.tar',cancerCode,cancerCode))
        end
        
    end
    
    % change back to the previous directory
    change_Dir
    
    % save the data to a .casv file
    writetable(mafFile,'mafFile_allcancer.csv') ;
    writetable(clinicalData,'all_clinicalData.csv') ;
    writetable(mutations,'mutations_allcancer.csv') ;
else
    % load the data that was prevously processed 
    mafFile = readtable('mafFile_allcancer.csv') ;
    clinicalData = readtable('all_clinicalData.csv');
    mutations = readtable('mutations_allcancer.csv') ;
end

end

% *********************** END of Internal Function ********************
% *********************** Another Internal Function *******************
% *********************************************************************

% Process mutation data from a MAF into a table 
function mutationTable = processMAF(MAFfile)

fprintf('\n Processing Mutations Annotation File \n')

% get the CCLE or TCGA ids and the genes in the table
try  % for CCLE data and TCGA
    caseIDs = unique(MAFfile.Tumor_Sample_Barcode) ;
    allGenes = unique(MAFfile.Hugo_Symbol)' ;
catch % for GDSC data
    % get the location of the variable names to change and change them to
    % the TCGA type IDS
    try
        % get teh position of the required variables
        pos1 = find( strcmp(MAFfile.Properties.VariableNames,'SAMPLE') ) ;
        pos2 = find( strcmp(MAFfile.Properties.VariableNames,'Gene') ) ;
        pos3 = find( strcmp(MAFfile.Properties.VariableNames,...
            'Classification') ) ;
        
        % change the variable names of required variables
        MAFfile.Properties.VariableNames([pos1,pos2,pos3]) = ...
            {'Tumor_Sample_Barcode','Hugo_Symbol','Variant_Type'} ;
        
        % get the genes and samples ids
        caseIDs = unique(MAFfile.Tumor_Sample_Barcode) ;
        allGenes = unique(MAFfile.Hugo_Symbol)' ;

    catch
        % change the variable names at the end of the gdscCNA data to make
        % them the same of the mutations data so they can be processed by
        % the MAF function
        MAFfile.Properties.VariableNames([1,end-1,end]) = ...
            {'Tumor_Sample_Barcode','Variant_Type','Hugo_Symbol'} ;
        caseIDs = unique(MAFfile.Tumor_Sample_Barcode) ;
        allGenes = unique(MAFfile.Hugo_Symbol)' ;
    end
    
end

% process the mutations data in loop 
for ii = 1:length(caseIDs)
    % get all the mutated genes for that sample id
    curMutations = MAFfile( strcmp( ...
        MAFfile.Tumor_Sample_Barcode, caseIDs{ii}),:) ;
    
    % remove duplicate gene mutations as they causing a lot of error and
    % also remove the silent mutations from the table
    curMutations(strcmp(curMutations.Variant_Type,'Silent'),:) = [] ;
    
    % run this part only for the TCGA data
    if ~exist('pos1','var')  
        % for deep MAP data
        if any(ismember(curMutations.Properties.VariableNames,'DepMap_ID'))
            [~,ia] = unique(curMutations(:,2),'rows','first') ;
            curMutations = curMutations(ia,:);
        else
            % for TCGA data
            [~,ia] = unique(curMutations(:,1),'rows','first') ;
            curMutations = curMutations(ia,:);
        end
    else
        % get only the first and last column 
        [~,ia] = unique(curMutations(:,4),'rows','first') ;
        curMutations = curMutations(ia,:);
    end

    % now compare the curMutations with allGenes this comparison is only
    % for the first row
    [~, posLocs]= intersect(allGenes(1,:),curMutations.Hugo_Symbol ) ;
    
    % add all to the genes list 
    allGenes(ii+1,posLocs') = curMutations.Variant_Type ; 
    
end

% now combine the two cell array and 

in to a table
mutationTable = cell2table([caseIDs, allGenes(2:end,:)] ) ;
mutationTable.Properties.VariableNames = ...
    matlab.lang.makeValidName ( ['SampleIDs',allGenes(1,:)]  );

% delete all the genes that do not have mutations in the table
toGo = all( cellfun(@isempty,mutationTable{:,:} ) );
mutationTable(:,toGo) = [] ;

end

% *********************** END of Internal Function ********************
% *********************** Another Internal Function *******************
% *********************************************************************

function change_Dir

% change back to the previous directory
try
    cd('/scratch/snkmus003/cancerMuts/allCancerMutations')
catch
    cd(['/Users/sinkala/Documents/MATLAB/cancerUKB_snps/',...
        'allCancerMutations'])
end
end

% *********************** END of Internal Function ********************
% *********************** Another Internal Function *******************
% *********************************************************************

% This function returns the alteration frequency for mutations and copy
% number data

function pathwayAlterations = find_MAPK_AlterationFreq(...
    metabolicPathways,mutations,cnaData)
% This is a table with columns as cancer types and row as metabolic
% pathways

% get the genes involved in a metabolic pathwy and return only these for
% the copy number data and mutations data

for ii = 1:height(metabolicPathways)
    
    % get the genes involved
    pathwayGenes = split(metabolicPathways.Genes(ii));
    pathwayMuts = mutations(:,[true, false, ...
        ismember(mutations.Properties.VariableNames(3:end), pathwayGenes)]);
    
    % process the copy number add
    if nargin == 3
        pathwayCopyNumber = cnaData(:,[true, false, ...
            ismember(cnaData.Properties.VariableNames(3:end),...
            pathwayGenes)] );
    end
    
    % get the mutatations in each samples
    pathwayMuts = addvars( pathwayMuts(:,1), ...
        double(any(~cellfun(@isempty,pathwayMuts{:,2:end}),2) ) , ...
        'NewVariableNames','Overall') ;
    pathwayMuts.CancerStudy = categorical(pathwayMuts.CancerStudy);
    
    % combine the two tables: ONLY IF there are also copy number
    % alterations
    if nargin == 3
        if any(ismember(cnaData.Properties.VariableNames(3:end),...
                pathwayGenes))
            
            % also get alterations for the copy number data. Sometimes the
            % data is cell if iam deleteion with GDSC data
            try % for TCGA and CCLE data
                pathwayCopyNumber2 = addvars( pathwayCopyNumber(:,1), ...
                    double( any(pathwayCopyNumber{:,2:end}, 2) ) , ...
                    'NewVariableNames','Overall') ;
            catch % for GDSC data
                pathwayCopyNumber2 = addvars( pathwayCopyNumber(:,1), ...
                    double(any(...
                    ~cellfun(@isempty,pathwayCopyNumber{:,2:end}),2) ),...
                    'NewVariableNames','Overall') ;
                
            end
            pathwayCopyNumber2.CancerStudy = ...
                categorical(pathwayCopyNumber2.CancerStudy);
            
            % add to the total mutations table
            pathwayMuts.Overall =  double( ...
                any([pathwayMuts.Overall,pathwayCopyNumber2.Overall] ,2) ) ;
        end
    end
    % convert the zeroes to NaN to make group stats easiler to do
    pathwayMuts.Overall(pathwayMuts.Overall == 0) = NaN ;
    
    % now get the group stats for the two tables: first get the stats for
    % the table without zeros and then with zeroes
    pathwayMuts = grpstats(pathwayMuts,'CancerStudy','numel') ;
%     pathwayCopyNumber =
%     grpstats(pathwayCopyNumber,'CancerStudy','numel');
    
    % create a table that has the over alterations percentage for both
    % mutations and copy number data
    if ii == 1
        pathwayAlterations = addvars(pathwayMuts(:,1), ...
            round( ...
            pathwayMuts.numel_Overall./pathwayMuts.GroupCount,3)*100,...
            'NewVariableNames', ...
            matlab.lang.makeValidName(metabolicPathways.pathwayName(ii)) );
    else % % join the two tables
        tempAlterations = addvars(pathwayMuts(:,1), ...
            round( ...
            pathwayMuts.numel_Overall./pathwayMuts.GroupCount,3)*100,...
            'NewVariableNames', ...
            matlab.lang.makeValidName(metabolicPathways.pathwayName(ii)) );
        
        pathwayAlterations = innerjoin(pathwayAlterations, tempAlterations);
    end
end

end

% *********************** END of Internal Function ********************
% *********************** Another Internal Function *******************
% *********************************************************************

function createLegendInternal(yPoint, xStart, legendLabels , plotColors,...
    myLgdTitle , fontSizes ,rectAndTextBox)

% specificy the y values starts and mode of actions for the drugs
% yPoint = 0.830 ; xStart = 0.1023 ;
xStartText = xStart + 0.01 ;
yPointTitle = yPoint + 0.03 ;

% specify the font size to be used in the plot
if ~exist('fontSizes','var')
    fontSizes = [10, 12] ;
end

% specifiy the rectangle and text length
if ~exist('rectAndTextBox','var')
    rectAndTextBox = [0.018 ,0.12] ;
end

% check for errors
if ~isnumeric(yPoint) || ~isnumeric(xStart)
    error('Both yPoint and xStarts should be numeric values')
elseif yPoint > 1 || xStart > 1
    error('Both yPoint and xStarts should be less than 1')
elseif ~isnumeric(plotColors)
    error('plot Color should be numeric')
end

if size(plotColors,1) ~= length(legendLabels)
    error('There should be a color for each legend names')
end

if iscategorical( legendLabels)
    legendLabels = categories(legendLabels);
end

for ii = 1:length(legendLabels)
    % add the legend color
    annotation('rectangle',[xStart yPoint rectAndTextBox(1) 0.023],...
        'EdgeColor', plotColors(ii,:), ...
        'FaceColor', plotColors(ii,:));
    
    % add the legend text
    annotation('textbox',[xStartText yPoint rectAndTextBox(2) 0.0230],...
        'String',legendLabels{ii},'FontSize',fontSizes(1),...
        'FontName','Helvetica Neue','FitBoxToText','off',...
        'EdgeColor',[1 1 1],'BackgroundColor',[1 1 1] , ...
        'VerticalAlignment','middle','FontWeight','normal')
    
    % move the y point down
    yPoint = yPoint - 0.03 ;
end

% add the title
annotation('textbox',[xStart yPointTitle rectAndTextBox(2) 0.0230],...
    'String', myLgdTitle,'FontSize',fontSizes(2),...
    'FontName','Helvetica Neue','FitBoxToText','off',...
    'EdgeColor',[1 1 1],'BackgroundColor',[1 1 1] , ...
    'VerticalAlignment','middle','FontWeight','bold',...
    'HorizontalAlignment','left');

end

% *********************** END of Internal Function ********************
% *********************** Another Internal Function *******************
% *********************************************************************

function colourBoxPlotInternal(plotData,groups, color, includeScatter)

% set the color to the box plots
if nargin == 2 || isempty(color)
    rng(6);
    color = rand(length(unique(groups )),3) ;
    if ~exist('includeScatter','var')
        includeScatter = false;
    end
end

% plot the data
boxplot(plotData,groups,'Color', color ,'Symbol','w+', ...
    'OutlierSize',5) ;

% set some figure properties and add title ot the figure
set(gca,'LineWidth',1.5,'Box','off')

% set the line width of the box plots
set(findobj(gca,'type','line'),'linew',2)
set(findobj(gca,'Tag','Lower Whisker'),'LineStyle','-')
set(findobj(gca,'Tag','Upper Whisker'),'LineStyle','-')

% set the color of the box plots
h4 = findobj(gca,'Tag','Box') ;
for kk=1:length(h4)
    patch(get(h4(kk),'XData'),get(h4(kk),'YData'),...
        color(kk,:),'FaceAlpha', 0.3,'LineStyle','-');
end

% here is the location of the plot
pointLoc = 5 ;

% add a scatter plot if we that is true
if includeScatter
   
    % get the unique groups 
    uniqueGroups = unique(groups) ;

    % add the scatter plots
    hold on
    
    for jj = 1:length(uniqueGroups)
        
        % add scatter plot to the box plots
        groupSc1 = plotData(groups == uniqueGroups(jj));
        
        % set the size the size of the marker
        makerSz = 30;
        
        % get only a smaller subset if the data points are too many
        if length(groupSc1) > 600
            groupSc1 = maxk(groupSc1,500) ;
            
            % change the markerSize
            makerSz = 15 ;
        end
        
        x = ones(length(groupSc1)).*(1+(rand(length(groupSc1))-0.5)/ ...
            pointLoc) ;
        
        % here is the first scatter plot
        scatter(x(:,1).*jj, groupSc1, makerSz, color(jj,:),'filled', ...
            'MarkerFaceColor',color(jj,:),'Marker','o',...
            'MarkerFaceAlpha',0.8)
        
        % here is the point location 
        pointLoc = pointLoc + 5 ;
        
    end
end

hold off

end

% *********************** END of Internal Function ********************
% *********************** Another Internal Function *******************
% *********************************************************************

% produce an upset plot for the data

function upSetPlot(inData,myColors)

% the function only accept a table
if nargin == 1
    error('Input should be one table')
end

% check for correct input
if ~istable(inData)
    error('inData should be a table or a matrix')
end
   
% get the column and row names
colNames = inData.Properties.VariableNames(2:end) ;
rowNames = flipud( inData.(1) ) ;

% convert colnames to cell array
if iscategorical(rowNames)
    rowNames = cellstr(rowNames) ;
end

% get the data and flip the pad
inData = flipud( inData{:,2:end} );

% add a horizontol bar graph of grey shades
axes('position',[0.15, 0.15, 0.65, 0.56]);
barh( 1:2:size(inData,1) , ...
     repmat( size(inData,2)+0.5 , length( 1:2:size(inData,1) ) ,1) , ...
    'FaceColor',[0.97 0.97 0.97] ,'EdgeColor',[0.97 0.97 0.97] , ...
    'BarWidth',0.5 )

% hold on to the figure
hold on

% specify the colors for everything else
everthingColor = [0.00,0.45,0.74] ;

% add the vertical lines connecting the points where both values are true
for ii = 1:size(inData,2)
    % get the y values where both inData are greater than 0
    curColumn = find( inData(:,ii) > 0 ) ;
    
    % if there are more than 2 data points then plot the data
    if length(curColumn) >= 2
        % plot plot the line
        plot([ii ii], [min(curColumn) max(curColumn)],...
            'LineWidth', 3 ,'Color', [0.7 0.7 0.7])
    end
end

% specifiy the circle size
if width(inData) < 40
    circSize = 1000 ;
else
    circSize = 500 ;
end

% plot the grey grid for the data
for ii = 1:size(inData,1)
    
    % specificy the color of positive values
    validColour = myColors.(rowNames{ii}) ;
    
    % plot the grey points for the data
    scatter(1:size(inData,2), ones(1,size(inData,2))*ii, ...
        circSize,'filled', ...
        'MarkerFaceColor',[0.7 0.7 0.7],...
        'MarkerEdgeColor',[0.7 0.7 0.7])
    
    % plot the coloured points for the data: these are the points that are
    % true: get the data that are greater than zero
    colorPoints = find( inData(ii,:) > 0 ) ;
          
    % produce a scatter plot of the data;
    scatter(colorPoints, ones(1,length(colorPoints))*ii, ...
        circSize,'filled',...
        'MarkerFaceColor', validColour,...
        'MarkerEdgeColor',validColour) 
end

% edit the figure properties
set(gca,'Box','Off','LineWidth',0.0001,...
    'XLim',[0.7 size(inData,2)+0.5] , ...
    'YLim',[0.7 size(inData,1)+0.5] , ...
    'XColor',[1 1 1] ,...
    'XTick',[], ...
    'XTickLabel','none', ...
    'YTick',1:size(inData,1), ...
    'YTickLabel',rowNames ,...
    'TickDir','out','FontSize', 14)

% add the text showing the total number of samples to the x-axis
text( 0.5, -0.05, ...
    strcat( num2str(sum(max(inData))), " total samples with mutations"),...
        'HorizontalAlignment','center',...
        'VerticalAlignment','middle', 'Units','Normalize', ...
        'FontSize',14)

% add a bar graph to the right of the figure I take the max because it will
% give me the only valid value allong each column
axes('position',[0.15, 0.715, 0.65, 0.15]);
bar( max(inData), 'BarWidth',0.5 ,'FaceColor', everthingColor );
ylabel('Size')

% add numbers to the top of the bar graph THIS CAN BE VECTORISED!!!!!!
y = max(inData) ;
x = 1:length(y);
for ii = 1:numel(y)
    text(x(ii),y(ii),num2str(y(ii),'%0.0f'),...
        'HorizontalAlignment','center',...
        'VerticalAlignment','bottom')
end

% adjust the figure
set(gca,'LineWidth',1,'FontSize',12 ,'Box','off',...
    'XTickLabel',[],'XLim',[0.7 size(inData,2)+0.5] ,'TickDir','out')

% add a bar graph to the top of the figure. 
axes('position',[0.80, 0.15, 0.05, 0.56]);
hb = barh( sum(inData,2),'BarWidth', 0.35 ,'FaceColor', 'flat',...
    'FaceAlpha',0.9) ;

% change the color of the second bars graphs
for ii = 1:length(rowNames)
    hb.CData(ii,:) = myColors.(rowNames{ii}) ;
end

% add numbers to the top of the bar graph
y = sum(inData,2) ;
x = 1:length(y);
for ii = 1:numel(y)
    text(y(ii),x(ii),num2str(y(ii),'%0.0f'),...
        'HorizontalAlignment','left',...
        'VerticalAlignment','middle')
end

% make sure there are no colors and spaces between the axis and the
% first and last bar
set(gca,'GridColor',[1 1 1], 'YLim', [0.7 size(inData,1)+0.5 ],...
    'YColor',[1 1 1] ,'XColor',[0.3 0.3 0.3],'FontSize',12,...
    'YTick',[],'Box','off','TickDir', 'out',...
    'LineWidth',1,'XAxisLocation','origin')
xlabel('Size')

hold off

end

% *********************** end of function ************************
% ****************************************************************

% find co-occurance and mutually exclusive mutations

function [hcom ,corrTable] = my_mutCorrelation(mutTable, includePlot)

% kdstr is the mutations table with 1s and 0s for each gene
if nargin == 1
    includePlot = false;
end

% plot mut-mut correlations: co-occurrence vs. mutually exclusive in
% primary and recurrent tumor samples, respectively.

genelist = mutTable.Properties.VariableNames(2:end)';
ng = numel(genelist);

% mutation table of primary samples
Pmat = mutTable{:,2:end}';

% here is the cancer study name
cancerName = char( mutTable.CancerStudy(1) ) ;

% **********************************************************

tumortype = cell(ng*ng - ng, 1);
genex = cell(ng*ng - ng, 1);
geney = cell(ng*ng - ng, 1);
gi = zeros(ng*ng - ng, 1);
gj = zeros(ng*ng - ng, 1);
dotx = zeros(ng*ng - ng, 1); % scatter x-axis
doty = zeros(ng*ng - ng, 1); % scatter y-axis
scatterSize = zeros(ng*ng - ng, 1); % scatter sizes
cr = zeros(ng*ng - ng, 3); % scatter colors
pval = ones(ng*ng - ng, 1);
odds = zeros(ng*ng - ng, 1);
numMutated = ones(length(genex),4) ;

corType = cell(ng*ng - ng, 1);

pvcut = 0.1; % specified in ng3590

t = 0;
for ii = 1:ng
    if ng > 100
        fprintf('\n Running the analysis for %s gene #%d of %d\n',...
            genelist{ii} , ii, ng)
    end
    for jj = 1:ng
        Z = zeros(2,2);
        if ii ~= jj % primary
            
            % check that the comparison has already been performed
            if ii > 1 || jj > 1
                % get the genes x array without empty parts
                aX = genex(~cellfun(@isempty,genex)) ;
                aY = geney(~cellfun(@isempty,geney)) ;
                
                % here is the comparison array
                compArray = [aX,aY] ;
                
                if ~isempty(compArray)                 
                    % check if they exist
                    compDone = any( all( ismember(compArray, ...
                        [ genelist(jj),genelist(ii) ] ),2 ) ) ;
                    
                    if compDone
                        continue
                    end
                end
            end
                
            % do the analysis
            t = t + 1;
            tumortype{t} = cancerName;
            
            % get the genes 
            genex{t} = genelist{ii};
            geney{t} = genelist{jj};
            
            % compared the mutation profile
            gi(t) = ii;
            gj(t) = jj;
            dotx(t) = jj;
            doty(t) = ng - ii + 1;
            
            % get the data for the fisher test and perform the test
            Z(1,1) = nnz(Pmat(ii,:) == 1 & Pmat(jj,:) == 1);
            Z(1,2) = nnz(Pmat(ii,:) == 1 & Pmat(jj,:) == 0);
            Z(2,1) = nnz(Pmat(ii,:) == 0 & Pmat(jj,:) == 1);
            Z(2,2) = nnz(Pmat(ii,:) == 0 & Pmat(jj,:) == 0);
            [~,p,~] = fishertest(Z);
            pval(t) = p;
            
            % odds ratio
            Z1 = Z + ones(2,2);
            oz = Z1(1,1)*Z1(2,2)/(Z1(1,2)*Z1(2,1));
            odds(t) = oz;
            
            % annotations
            if p < pvcut
                scatterSize(t) = -log10(p);
                if oz > 1
                    cr(t,:) = [1 0 0]; % red: co-mut
                    corType(t) = {'co-occurrence'} ;
                else
                    cr(t,:) = [0 1 0]; % green: mutual exclusive
                    corType(t) = {'mutual exclusivity'} ;
                end
            else
                scatterSize(t) = 1;
                cr(t,:) = [0.75 0.75 0.75]; % grey
                corType(t) = {'none'} ;
            end
            
            % put the number of mutated samples in a table 
            numMutated(t,:) = Z(:)' ;
        end
    end
end

% here is the correlation table
corrTable = table(tumortype,genex,geney,dotx,doty,scatterSize,...
    corType,odds,pval);
numMutated = array2table(numMutated,'VariableNames', ...
    {'MutatedBoth','MutatedX','MutatedY','NoMutated'}) ;
corrTable = [corrTable,numMutated] ;

corrTable = sortrows(corrTable,'pval','ascend') ;

% **********************************************************

if includePlot
    figure('position',[0 600 1200 500])
    hold on
    
    yyaxis left
    hcom = scatter(dotx,doty,scatterSize*75,cr,'filled',...
        'MarkerEdgeColor','k');
    
    xlim([-(ng+1),ng+1])
    ylim([0,ng+1])
    
    for ii = 2:ng
        text(0,ng - ii + 1,genelist{ii},'horizontalalignment',...
            'center','fontsize',12)
    end
    
    for ii = 1:(ng-1)
        ht = text(ii + 0.4,ng - ii + 0.4,genelist{ii},...
            'horizontalalignment','left','fontsize',12);
        ht.Rotation = 45;
    end
    
    % % for the text on the right
    % for i = 1:(ng-1)
    %     ht = text(- i - 0.4,ng - i + 0.4,genelist{i},...
    %       'horizontalalignment','right','fontsize',12);
    %     ht.Rotation = 360-45;
    % end
    
    set(gca,'visible','off')
    hold off
else
    hcom = [];
end
end





