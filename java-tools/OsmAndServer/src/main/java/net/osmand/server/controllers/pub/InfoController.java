package net.osmand.server.controllers.pub;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Configuration
@PropertySource("classpath:git.properties")
public class InfoController {

	protected static final Log logger = LogFactory.getLog(InfoController.class);
	

    @Value("${git.commit.format}")
    private String commit;
    

    @RequestMapping("/info")
    public String index() {
        return String.format("OsmAnd Live server. Revision: %s", commit);
    }

}