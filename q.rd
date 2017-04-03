<resource>
    <schema>bdhne</schema>
    <meta name="title">IcraNet Binary-driven HyperNovae on GRB catalog</meta>
    <meta name="creationDate">2017-03-20T01:02:03</meta>
    <meta name="description">
        It is provided a list of 173 GRB events related to binary-driven
        Hypernovae (IBdHNe) spanning 12 years of Swift/XRT observation.
        In the table we report important
        observational features: redshift (z), isotropic energy (E_iso),
        observing instrument in the gamma-ray band, and correspondent
        NASA GCN circular from which we take the gamma-ray spectral
        parameters in order to estimate E_iso.
    </meta>
    <meta name="creator.name">IcraNet</meta>
    <meta name="subject">Catalogs</meta>
    <meta name="subject">Very High Energy</meta>
    <meta name="subject">Gamma-ray</meta>
    <meta name="type">Catalog</meta>
    <meta name="coverage">
        <meta name="profile">AllSky ICRS</meta>
    </meta>
    <meta name="source">
        2017 in preparation
    </meta>

    <table id="main" onDisk="True">

        <column name="GRB" type="text"
            ucd="meta.id;meta.main"
            description="GRB name"/>

        <column name="designation" type="text"
            ucd="meta.id"
            description="Designation"/>

        <column name="z" type="real"
            ucd="src.redshift"
            description="Estimated redshift"/>

        <column name="E_iso" type="real"
            unit="1e+52 erg" ucd="em.energy"
            description="Isotropic energy"/>

        <column name="instrument" type="text"
            ucd="instr.tel"
            description="Observing instrument"/>

        <column name="GCN" type="integer"
            ucd="meta.id"
            description="GCN circular number"/>

<!--
        <column name="ra" type="double precision"
            unit="degree" ucd="pos.eq.ra;meta.main"
            description="Right Ascension"/>

        <column name="dec" type="double precision"
            unit="degree" ucd="pos.eq.dec;meta.main"
            description="Declination"/>

        <column name="lii" type="double precision"
            unit="degrees" ucd="pos.galactic.lon"
            description="Galactic longitude"/>

        <column name="bii" type="double precision"
            unit="degrees" ucd="pos.galactic.lat"
            description="Galactic latidude"/>

        <column name="epoch_mjd" type="real"
            unit="d" ucd="time.epoch"
            description="Epoch MJD">
		<values nullLiteral="0"/>
	</column>

        <column name="epoch_date" type="date"
            unit="y" ucd="time.epoch"
            description="Epoch year">
		<values nullLiteral="1900-01-01"/>
	</column>
-->

    </table>

    <data id="import">
        <sources>data/data.csv</sources>
        <csvGrammar
            delimiter=";"
            preFilter="sed '/^#/d;s/\s\{1,\};\s\{1,\}/;/g'"
        />
        <make table="main">
            <rowmaker idmaps="*"/>
        </make>
    </data>

<!--
<productCore queriedTable="main"/>

    <pythonCore>
        <coreProc>
            <code>
                rows = [{"foo": 3*i, "bar": 8*i} for i in range(30)]
                return rsc.TableForDef(self.outputTable, rows=rows)
            </code>
        </coreProc>
    </pythonCore>
    <publish render="static" sets="local"/>
    </service>

-->
    <service id="web" allowed="form,static">
        <meta name="shortName">BdHNe</meta>
        <dbCore queriedTable="main" limit="200">
            <condDesc buildFrom="GRB"/>
            <condDesc buildFrom="z"/>
            <condDesc buildFrom="E_iso"/>
        </dbCore>
        <publish render="form" sets="local"/>
    </service>
<!--            <outputTable verbLevel="20"/-->

</resource>
